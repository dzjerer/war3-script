/*
 * TriggerSleepActionByTimer (v0.0)
 *
 * 함수:
 *   function TriggerSleepActionByTimer takes real timeout returns nothing
 *     일정 시간 동안 대기합니다.
 *     트리거 액션 속에서만 작동합니다.
 *     timeout: 대기할 시간 (초)
 */
library TriggerSleepActionByTimer initializer Init requires /*
    */ MemoryLib, /* https://github.com/heoh/war3-memory-lib (>= v0.1-alpha)
    */ TimerUtils

    globals
        private constant real TIMEOUT_INFINITE = 1000000000.0

        private integer pGameWar3
    endglobals


    private function sub_95DD0 takes integer a1 returns integer
        local Ptr pFunc = pGameDll + 0x95DD0
        call SaveStr(JNProc_ht, JNProc_key, 0, "(I)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, a1)
        if (JNProcCall(JNProc__fastcall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_2CB880 takes integer this, integer a2 returns nothing
        local Ptr pFunc = pGameDll + 0x2CB880
        call SaveStr(JNProc_ht, JNProc_key, 0, "(II)V")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        call JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)
    endfunction

    private function GetGameWar3 takes nothing returns Ptr
        return PtrPtr[pGameDll + 0xD305E0]
    endfunction

    private function GetCurrentTriggerExecution takes nothing returns Ptr
        local integer triggerExecutionsSize = IntPtr[pGameWar3 + 0x10]
        local PtrPtr triggerExecutions = PtrPtr[pGameWar3 + 0x14]
        if (triggerExecutionsSize <= 0) then
            return 0
        endif
        return triggerExecutions[triggerExecutionsSize - 1]
    endfunction

    private function ResumeTriggerExecution takes Ptr pTriggerExecution returns nothing
        call sub_2CB880(pTriggerExecution, IntPtr[pTriggerExecution + 0x90])
    endfunction

    private function AwakeCallback takes nothing returns nothing
        local timer t = GetExpiredTimer()
        local Ptr pTriggerExecution = GetTimerData(t)
        call ReleaseTimer(t)
        set t = null

        call ResumeTriggerExecution(pTriggerExecution)
    endfunction

    function TriggerSleepActionByTimer takes real timeout returns nothing
        local integer v0 = sub_95DD0(5)
        local IntPtr v1 = PtrPtr[IntPtr[v0 + 12] + 4 * IntPtr[v0 + 20] - 4]
        local Ptr pTriggerExecution = GetCurrentTriggerExecution()
        local timer t

        if (pTriggerExecution != 0) then
            set t = NewTimer()
            call SetTimerData(t, pTriggerExecution)
            call TimerStart(t, timeout, false, function AwakeCallback)
            set t = null
        endif

        call TriggerSleepAction(TIMEOUT_INFINITE)
    endfunction


    private function Init takes nothing returns nothing
        set pGameWar3 = GetGameWar3()
    endfunction

endlibrary
