//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using Antmicro.Migrant;
using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Utilities;
using TermSharp.Vt100;

namespace Antmicro.Renode.Integrations
{
    public static class AsciinemaRecorderExtensions
    {
        public static void RecordToAsciinema(this IUART uart, string filePath, bool useVirtualTimeStamps = false, int width = 80, int height = 24)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            if(!emulation.TryGetMachineForPeripheral(uart, out var machine))
            {
                throw new RecoverableException("Could not find machine for the given UART");
            }
            var name = machine.GetAnyNameOrTypeName(uart);
            var machineName = emulation[machine];
            var recorder = new AsciinemaRecorder(filePath, machine, name, useVirtualTimeStamps, width, height);
            emulation.ExternalsManager.AddExternal(recorder, $"{machineName}-{name}-recorder");
            emulation.Connector.Connect(uart, recorder);
        }
    }

    [Transient]
    public class AsciinemaRecorder: IConnectable<IUART>, IDisposable, IExternal
    {
        public AsciinemaRecorder(string filePath, IMachine machine, string name, bool useVirtualTimeStamps, int width, int height)
        {
            this.filePath = filePath;
            this.name = name;
            this.machine = machine;
            this.decoder = new ByteUtf8Decoder(HandleCharReceived);
            this.height = height;
            this.width = width;
            this.useVirtualTimeStamps = useVirtualTimeStamps;
        }

        public void AttachTo(IUART uart)
        {
            this.uart = uart;
            this.uart.CharReceived += decoder.Feed;
            writer = new StreamWriter(filePath);
            writer.WriteLine(String.Format(Header, width, height, name));
        }

        public void DetachFrom(IUART uart)
        {
            if(this.uart != uart)
            {
                throw new ArgumentException($"Trying to detach unattached UART from {this.GetType().Name}");
            }
            this.uart.CharReceived -= decoder.Feed;
            Dispose();
        }

        public void Dispose()
        {
            writer?.Close();
            writer = null;
        }

        private void HandleCharReceived(string data)
        {
            data = EncodeNonPrintableCharacters(data);
            double time;
            if(useVirtualTimeStamps)
            {
                time = machine.LocalTimeSource.ElapsedVirtualTime.TotalSeconds;
            }
            else
            {
                time = machine.LocalTimeSource.ElapsedHostTime.TotalSeconds;
            }
            writer.WriteLine(String.Format(EntryTemplate, time, data));
        }

        static string EncodeNonPrintableCharacters(string value)
        {
            foreach(var mapping in mappings)
            {
                value = value.Replace(mapping.Item1, mapping.Item2);
            }
            var builder = new StringBuilder();
            var nonPrintable = new UnicodeCategory[]
            {
                UnicodeCategory.Control,
                UnicodeCategory.OtherNotAssigned,
                UnicodeCategory.Surrogate
            };
            foreach(var c in value)
            {
                if(nonPrintable.Contains(char.GetUnicodeCategory(c)) || char.IsControl(c))
                {
                    var encodedValue = "\\u" + ((int)c).ToString("x4");
                    builder.Append(encodedValue);
                }
                else
                {
                    builder.Append(c);
                }
            }
            return builder.ToString();
        }

        private static List<Tuple<string, string>> mappings = new List<Tuple<string, string>>
        {
            {"\\",     "\\\\"},
            {"\u0007", "\\a"},
            {"\u0008", "\\b"},
            {"\u0009", "\\t"},
            {"\u000a", "\\n"},
            {"\u000b", "\\v"},
            {"\u000c", "\\f"},
            {"\u000d", "\\r"},
            {"\"",     "\\\""}
        };

        private StreamWriter writer;
        private IUART uart;

        private readonly ByteUtf8Decoder decoder;
        private readonly string name;
        private readonly IMachine machine;
        private readonly bool useVirtualTimeStamps;
        private readonly string filePath;
        private readonly int width;
        private readonly int height;
        private const string EntryTemplate = "[{0}, \"o\", \"{1}\"]";
        private const string Header = "{{\"version\": 2, \"width\": {0}, \"height\": {1}, \"name\": \"{2}\", \"env\": {{\"TERM\": \"xterm-256color\"}}}}";
    }
}
