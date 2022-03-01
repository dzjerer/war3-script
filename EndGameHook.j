//! import "JNMemory.j"
//! import "JNCommon.j"

/*
 * EndGameHook (v0.0)
 *
 * 함수:
 *   function SetGameEndCallback takes string func returns nothing
 *     게임이 종료될 때 호출되는 함수를 이름으로 지정합니다.
 *     func: 콜백 함수 이름
 *
 *   function SetGameEndCallbackByCode takes code funcHandle returns nothing
 *     게임이 종료될 때 호출되는 함수를 code 타입으로 지정합니다.
 *     funcHandle: 콜백 함수
 */
library EndGameHook initializer Init requires MemoryLib, Typecast

    globals
        private integer pGameWar3
        private integer pSub_35FDF0
        private integer pTrampoline
        private integer pCallback
        private integer pCallbackCodeIndex
        private integer MemoryBlockOldProtect
        private integer pDummy1
        private integer pDummy2
        private integer array originalSub_35FDF0

        private string userCallbackName = null
        private code userCallbackCode = null
    endglobals


    function SetGameEndCallback takes string func returns nothing
        set userCallbackName = func
        set userCallbackCode = null
    endfunction

    function SetGameEndCallbackByCode takes code funcHandle returns nothing
        set userCallbackName = null
        set userCallbackCode = funcHandle
    endfunction


    //! runtextmacro MemoryLib_DefineMemoryBlock("private", "MemoryBlock", "GameExitHook__MemoryBlock", "400")

    private function GetGameWar3 takes nothing returns Ptr
        return PtrPtr[pGameDll + 0xD305E0]
    endfunction

    private function VirtualProtect takes Ptr lpAddress, integer dwSize, integer flNewProtect, Ptr pflOldProtect returns integer
        local Ptr pFunc = IntPtr[pGameDll + 0xA6B384]
        call SaveStr(JNProc_ht, JNProc_key, 0, "(IIII)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, lpAddress)
        call SaveInteger(JNProc_ht, JNProc_key, 2, dwSize)
        call SaveInteger(JNProc_ht, JNProc_key, 3, flNewProtect)
        call SaveInteger(JNProc_ht, JNProc_key, 4, pflOldProtect)
        if (JNProcCall(JNProc__stdcall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_8BED60 takes Ptr this returns Ptr
        local Ptr pFunc = pGameDll + 0x8BED60
        call SaveStr(JNProc_ht, JNProc_key, 0, "(I)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_8CB7D0 takes Ptr this, Ptr a2 returns integer
        local Ptr pFunc = pGameDll + 0x8CB7D0
        call SaveStr(JNProc_ht, JNProc_key, 0, "(II)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function GetCodeIndex takes code c returns integer
        local integer pCode = C2I(c)
        local integer v1 = IntPtr[pGameWar3 + 8]
        local integer v2 = sub_8BED60(v1)
        local integer index = sub_8CB7D0(v2, pCode)
        return index
    endfunction

    private function MakeMemoryBlockExecutable takes nothing returns nothing
        call VirtualProtect(MemoryBlock.pHead, MemoryBlock.size, 0x40, MemoryBlock.pHead)
        set MemoryBlockOldProtect = IntPtr[MemoryBlock.pHead]
    endfunction

    private struct AssemblyWriter
        public Ptr pCursor

        public static method create takes Ptr pHead returns thistype
            local thistype this = thistype.allocate()
            set this.pCursor = pHead
            return this
        endmethod

        public method malloc takes integer size returns Ptr
            local Ptr pBlock = this.pCursor
            set this.pCursor = this.pCursor + size
            return pBlock
        endmethod

        public method writePadding takes integer size returns nothing
            local integer i = 0
            loop
                exitwhen i >= size
                set BytePtr[this.pCursor] = 0xCC
                set this.pCursor = this.pCursor + 1
                set i = i + 1
            endloop
        endmethod

        public method writeByte takes integer byteValue returns nothing
            set BytePtr[this.pCursor] = byteValue
            set this.pCursor = this.pCursor + 1
        endmethod

        public method writeInt takes integer intValue returns nothing
            set IntPtr[this.pCursor] = intValue
            set this.pCursor = this.pCursor + 4
        endmethod

        public method writeOffset takes integer address returns nothing
            set IntPtr[this.pCursor] = address - (this.pCursor + 4)
            set this.pCursor = this.pCursor + 4
        endmethod
    endstruct

    private function InitMemoryBlock takes nothing returns nothing
        local AssemblyWriter asm
        local integer headerSize

        call MakeMemoryBlockExecutable()

        set asm = AssemblyWriter.create(MemoryBlock.pHead)

        set pDummy1 = asm.malloc(4)
        set pDummy2 = asm.malloc(4)

        call asm.writePadding(8)

        // [callback function]
        //  void callback() {
        //      int eax;
        //      int ebx;
        //      ebx = 0x00;  // callback code
        //      if (ebx != 0) {
        //          eax = sub_2135F0(pGameWar3)  // Get GameState
        //          eax = sub_2B97A0(eax, ebx)   // Get JassFunc
        //          sub_22ABF0(eax, pDummy1, pDummy2, 1, 0, 0)  // Execute Func
        //          if (*pDummy2) {
        //              sub_8C2260(*pDummy2)
        //          }
        //      }
        //  }
        set pCallback = asm.pCursor
        // Function header
        call asm.writeByte(0x55)        // push ebp
        call asm.writeByte(0x8B)        // mov ebp, esp
        call asm.writeByte(0xEC)        // -
        call asm.writeByte(0x53)        // push ebx
        call asm.writeByte(0x51)        // push ecx
        call asm.writeByte(0x52)        // push edx

        // Check callback is not 0
        set pCallbackCodeIndex = asm.pCursor + 1
        call asm.writeByte(0xBB)        // mov ebx, 0x00000000
        call asm.writeInt(0x00000000)   // -
        call asm.writeByte(0x85)        // test ebx, ebx
        call asm.writeByte(0xDB)        // -
        call asm.writeByte(0x74)        // je +60
        call asm.writeByte(60)          // -

        // Get GameState
        call asm.writeByte(0xB9)        // mov ecx, pGameWar3
        call asm.writeInt(pGameWar3)    // -
        call asm.writeByte(0xE8)        // call sub_2135F0
        call asm.writeOffset(pGameDll + 0x2135F0)   // -

        // Get JassFunc
        call asm.writeByte(0x53)        // push ebx
        call asm.writeByte(0x8B)        // mov ecx, eax
        call asm.writeByte(0xC8)        // -
        call asm.writeByte(0xE8)        // call sub_2B97A0
        call asm.writeOffset(pGameDll + 0x2B97A0)   // -

        // Execute JassFunc
        call asm.writeByte(0x8B)        // mov ecx, eax
        call asm.writeByte(0xC8)        // -
        call asm.writeByte(0x6A)        // push 0
        call asm.writeByte(0x00)        // -
        call asm.writeByte(0x6A)        // push 0
        call asm.writeByte(0x00)        // -
        call asm.writeByte(0x6A)        // push 1
        call asm.writeByte(0x01)        // -
        call asm.writeByte(0x68)        // push pDummy2
        call asm.writeInt(pDummy2)      // -
        call asm.writeByte(0x68)        // push pDummy1
        call asm.writeInt(pDummy1)      // -
        call asm.writeByte(0xE8)        // call sub_22ABF0
        call asm.writeOffset(pGameDll + 0x22ABF0)   // -

        // Check dummy2 is not 0
        call asm.writeByte(0xA1)        // mov eax, [pDummy2]
        call asm.writeInt(pDummy2)      // -
        call asm.writeByte(0x85)        // test eax, eax
        call asm.writeByte(0xC0)        // -
        call asm.writeByte(0x74)        // je +10
        call asm.writeByte(10)          // -

        // Call sub_8C2260(dummy2)
        call asm.writeByte(0xB9)        // mov ecx, [pDummy2]
        call asm.writeInt(pDummy2)      // -
        call asm.writeByte(0xE8)        // call sub_8C2260
        call asm.writeOffset(pGameDll + 0x8C2260)   // -

        // Function footer
        call asm.writeByte(0x5A)        // pop edx
        call asm.writeByte(0x59)        // pop ecx
        call asm.writeByte(0x5B)        // pop ebx

        call asm.writeByte(0x8B)        // mov esp, ebp
        call asm.writeByte(0xE5)        // -
        call asm.writeByte(0x5D)        // pop ebp
        call asm.writeByte(0xC3)        // ret

        call asm.writePadding(8)

        // [trampoline block]
        set pTrampoline = asm.pCursor
        // Function header
        call asm.writeByte(0x55)        // push ebp
        call asm.writeByte(0x8B)        // mov ebp, esp
        call asm.writeByte(0xEC)        // -
        call asm.writeByte(0x83)        // sub esp, 08
        call asm.writeByte(0xEC)        // -
        call asm.writeByte(0x08)        // -

        set headerSize = asm.pCursor - pTrampoline

        call asm.writeByte(0xE8)        // call pCallback
        call asm.writeOffset(pCallback)   // -

        call asm.writeByte(0xE9)        // jmp pReturn
        call asm.writeOffset(pSub_35FDF0 + headerSize)   // -

        call asm.writePadding(8)

        // Initialize globals
        set IntPtr[pDummy1] = 0
        set IntPtr[pDummy2] = 0

        call asm.destroy()
    endfunction

    private function IsHookedAlready takes nothing returns boolean
        return IntPtr[pSub_35FDF0] != 0x83EC8B55
    endfunction

    private function HookEndGame takes nothing returns nothing
        local AssemblyWriter asm

        // Backup sub_35FDF0
        set originalSub_35FDF0[0] = IntPtr(pSub_35FDF0)[0]
        set originalSub_35FDF0[1] = IntPtr(pSub_35FDF0)[1]

        // Inject trampoline into sub_35FDF0
        set asm = AssemblyWriter.create(pSub_35FDF0)
        call asm.writeByte(0xE9)        // jmp pTrampoline
        call asm.writeOffset(pTrampoline)   // -
        call asm.writeByte(0x90)        // nop
        call asm.destroy()
    endfunction

    private function UnhookEndGame takes nothing returns nothing
        // Restore sub_35FDF0
        set IntPtr(pSub_35FDF0)[0] = originalSub_35FDF0[0]
        set IntPtr(pSub_35FDF0)[1] = originalSub_35FDF0[1]
    endfunction

    private function SetEndGameHookCallback takes code func returns nothing
        set IntPtr[pCallbackCodeIndex] = GetCodeIndex(func)
    endfunction

    private function Callback takes nothing returns nothing
        call UnhookEndGame()

        if (userCallbackName != null) then
            call ExecuteFunc(userCallbackName)
        elseif (userCallbackCode != null) then
            call ForForce(GetForceOfPlayer(Player(0)), userCallbackCode)
        endif
    endfunction

    private function InitHook takes nothing returns nothing
        if IsHookedAlready() then
            debug call JNWriteLog("[EndGameHook] The function is hooked already.")
            return
        endif

        call InitMemoryBlock()
        call HookEndGame()
    endfunction

    private function Init takes nothing returns nothing
        set pGameWar3 = GetGameWar3()
        set pSub_35FDF0 = pGameDll + 0x35FDF0
        call InitHook()
        call SetEndGameHookCallback(function Callback)
    endfunction

endlibrary
