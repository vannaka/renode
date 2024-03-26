//
// Copyright (c) 2010-2023 Antmicro
//
//  This file is licensed under the MIT License.
//  Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
using System.Runtime.ExceptionServices;
using ELFSharp.ELF;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.CPU.Registers;
using Machine = Antmicro.Renode.Core.Machine;

namespace Antmicro.Renode.Peripherals.Verilated
{
    public partial class VerilatedRiscV32 : VerilatedCPU, ICpuSupportingGdb
    {
        public VerilatedRiscV32(string cpuType, Machine machine, Endianess endianness = Endianess.LittleEndian, 
        CpuBitness bitness = CpuBitness.Bits32, string simulationFilePathLinux = null, 
        string simulationFilePathWindows = null, string simulationFilePathMacOS = null, string address = null)
            : base(cpuType, machine, endianness, bitness, simulationFilePathLinux, simulationFilePathWindows, simulationFilePathMacOS, address)
        {
        }

        public override string Architecture { get { return "riscv"; } }

        public string GDBArchitecture { get { return "riscv:rv32"; } }

        public List<GDBFeatureDescriptor> GDBFeatures { get { return new List<GDBFeatureDescriptor>(); } }

        public void SetRegisterUnsafe(int register, RegisterValue value)
        {
            if(!mapping.TryGetValue((VerilatedRiscV32Registers)register, out var r))
            {
                throw new RecoverableException($"Wrong register index: {register}");
            }
            if(r.IsReadonly)
            {
                throw new RecoverableException($"Register: {register} value is not writable.");
            }

            SetRegisterValue32(r.Index, checked((UInt32)value));
        }

        public RegisterValue GetRegisterUnsafe(int register)
        {
            if(!mapping.TryGetValue((VerilatedRiscV32Registers)register, out var r))
            {
                throw new RecoverableException($"Wrong register index: {register}");
            }
            return GetRegisterValue32(r.Index);
        }

        public IEnumerable<CPURegister> GetRegisters()
        {
            return mapping.Values.OrderBy(x => x.Index);
        }

        public void EnterSingleStepModeSafely(HaltArguments args, bool? blocking = null)
        {
            // this method should only be called from CPU thread,
            // but we should check it anyway
            CheckCpuThreadId();
            ChangeExecutionModeToSingleStep(blocking);

            UpdateHaltedState();
            InvokeHalted(args);
        }

        public void AddHookAtInterruptBegin(Action<ulong> hook)
        {
            this.Log(LogLevel.Warning, "AddHookAtInterruptBegin not implemented");
        }

        public void AddHookAtInterruptEnd(Action<ulong> hook)
        {
            this.Log(LogLevel.Warning, "AddHookAtInterruptEnd not implemented");
        }

        public void AddHook(ulong addr, Action<ICpuSupportingGdb, ulong> hook)
        {
            this.Log(LogLevel.Warning, "AddHook not implemented");
        }

        public void RemoveHook(ulong addr, Action<ICpuSupportingGdb, ulong> hook)
        {
            this.Log(LogLevel.Warning, "RemoveHook not implemented");
        }

        public void AddHookAtWfiStateChange(Action<bool> hook)
        {
            this.Log(LogLevel.Warning, "AddHookAtWfiStateChange not implemented");
        }

        public void RemoveHooksAt(ulong addr)
        {
            this.Log(LogLevel.Warning, "RemoveHooksAt not implemented");
        }

        public void RemoveAllHooks()
        {
            this.Log(LogLevel.Warning, "RemoveAllHooks not implemented");
        }
    }
}
