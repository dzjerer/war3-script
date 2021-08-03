/*
 * SmartCastSystem (2021-08-04)
 *
 * 함수:
 *   function SmartCastSystem_SetAbilityTriggerType takes integer abilityId, integer triggerType returns nothing
 *     특정 어빌리티의 스마트 캐스팅 작동 방식을 지정합니다.
 *   function SmartCastSystem_UnsetAbilityTriggerType takes integer abilityId returns nothing
 *     특정 어빌리티의 스마트 캐스팅 작동 방식을 해제합니다.
 *   function SmartCastSystem_SetDefaultTriggerType takes integer triggerType returns nothing
 *     기본 스마트 캐스팅 작동 방식을 지정합니다. (기본값: SmartCastSystem_TRIGGER_TYPE_NONE)
 *
 *   function SmartCastSystem_SetIgnoreWhenTargetingFails takes boolean flag returns nothing
 *     유닛 타겟형 어빌리티의 스마트 캐스팅에 실패해도 목표물 선택 커서를 표시하지 않습니다.
 *     (기본값: true)
 *   function SmartCastSystem_EnableMultiUnitSmartCast takes boolean flag returns nothing
 *     여러 유닛을 선택했을 때, 동시에 스마트 캐스팅을 허용합니다.
 *     (기본값: true)
 *
 * TRIGGER_TYPE(작동 방식):
 *   SmartCastSystem_TRIGGER_TYPE_NONE
 *     스마트 캐스팅을 사용하지 않습니다.
 *   SmartCastSystem_TRIGGER_TYPE_ALWAYS
 *     항상 스마트 캐스팅이 작동합니다.
 *   SmartCastSystem_TRIGGER_TYPE_SHIFT_DOWN
 *     Shift 키를 눌렀을 때에만 스마트 캐스팅이 작동합니다.
 *   SmartCastSystem_TRIGGER_TYPE_SHIFT_UP
 *     Shift 키를 놓았을 때에만 스마트 캐스팅이 작동합니다.
 */

//! import "DzAPIFrameHandle.j"
//! import "DzAPIHardware.j"
//! import "DzAPIPlus.j"
//! import "DzAPISync.j"
//! import "JAPIAbilityState.j"
//! import "JNCommon.j"

library SmartCastSystem initializer Init requires DzAPIFrameHandle, DzAPIHardware, DzAPIPlus, DzAPISync, JAPIAbilityState, JNCommon
    globals
        private constant string SYNC_PREFIX = "SmartCast"

        private constant integer COMMAND_BAR_ROWS = 3
        private constant integer COMMAND_BAR_COLUMNS = 4

        private constant integer TABLE_TRIGGER_TYPE_KEY = 1
        public constant integer TRIGGER_TYPE_NONE = 0
        public constant integer TRIGGER_TYPE_ALWAYS = 1
        public constant integer TRIGGER_TYPE_SHIFT_DOWN = 2
        public constant integer TRIGGER_TYPE_SHIFT_UP = 3

        private constant integer ORDER_TYPE_IMMEDIATE = 0x1
        private constant integer ORDER_TYPE_POINT = 0x2
        private constant integer ORDER_TYPE_TARGET = 0x4

        private constant integer COMMAND_BUTTON_STATE_COOLDOWN = 0
        private constant integer COMMAND_BUTTON_STATE_NOT_ENOUGH_MANA = 1
        private constant integer COMMAND_BUTTON_STATE_READY = 2

        private trigger keyPressHandler
        private trigger syncHandler
        private timer targetingUIHandler
        private hashtable table = InitHashtable()
        private group selectionGroup = CreateGroup()
        private boolean removingTargetingUI = false
        private integer defaultTriggerType = TRIGGER_TYPE_NONE
        private boolean ignoreWhenTargetingFails = true
        private boolean multiUnitSmartCastEnabled = true
    endglobals

    public function SetAbilityTriggerType takes integer abilityId, integer triggerType returns nothing
        call SaveInteger(table, abilityId, TABLE_TRIGGER_TYPE_KEY, triggerType)
    endfunction

    public function UnsetAbilityTriggerType takes integer abilityId returns nothing
        call FlushChildHashtable(table, abilityId)
    endfunction

    public function SetDefaultTriggerType takes integer triggerType returns nothing
        set defaultTriggerType = triggerType
    endfunction

    public function SetIgnoreWhenTargetingFails takes boolean flag returns nothing
        set ignoreWhenTargetingFails = flag
    endfunction

    public function EnableMultiUnitSmartCast takes boolean flag returns nothing
        set multiUnitSmartCastEnabled = flag
    endfunction

    private function GetAbilityTriggerType takes integer abilityId returns integer
        if not HaveSavedInteger(table, abilityId, TABLE_TRIGGER_TYPE_KEY) then
            return defaultTriggerType
        endif
        return LoadInteger(table, abilityId, TABLE_TRIGGER_TYPE_KEY)
    endfunction

    private function I2U takes integer id returns unit
        call SaveFogStateHandle(table, 0, 0, ConvertFogState(id))
        return LoadUnitHandle(table, 0, 0)
    endfunction

    private function ChatInputFrameIsVisible takes nothing returns boolean
        return JNMemoryGetByte(JNGetModuleHandle("Game.dll") + 0x00D04FEC) != 0
    endfunction

    private function GetCommandBarButtonData takes integer btnPtr returns integer
        return JNMemoryGetInteger(btnPtr + 0x190)
    endfunction

    private function GetCommandBarButtonHotkey takes integer btnPtr returns integer
        local integer dataPtr = GetCommandBarButtonData(btnPtr)
        if (dataPtr != 0) then
            return JNMemoryGetInteger(dataPtr + 0x5AC)
        endif
        return 0
    endfunction

    private function GetCommandBarButtonAbilityId takes integer btnPtr returns integer
        local integer dataPtr = GetCommandBarButtonData(btnPtr)
        if (dataPtr != 0) then
            return JNMemoryGetInteger(dataPtr + 0x4)
        endif
        return 0
    endfunction

    private function GetCommandBarButtonOrderId takes integer btnPtr returns integer
        local integer dataPtr = GetCommandBarButtonData(btnPtr)
        if (dataPtr != 0) then
            return JNMemoryGetInteger(dataPtr + 0x8)
        endif
        return 0
    endfunction

    private function GetCommandBarButtonOrderType takes integer btnPtr returns integer
        local integer dataPtr = GetCommandBarButtonData(btnPtr)
        if (dataPtr != 0) then
            return JNMemoryGetInteger(dataPtr + 0x10)
        endif
        return 0
    endfunction

    private function GetCommandBarButtonState takes integer btnPtr returns integer
        local integer dataPtr = GetCommandBarButtonData(btnPtr)
        if (dataPtr != 0) then
            return JNMemoryGetInteger(dataPtr + 0x6D0)
        endif
        return 0
    endfunction

    private function GetCommandBarButtonByHotkey takes integer hotkey returns integer
        local integer x
        local integer y
        local integer btnPtr

        set y = 0
        loop
            exitwhen (y >= COMMAND_BAR_ROWS)

            set x = 0
            loop
                exitwhen (x >= COMMAND_BAR_COLUMNS)

                set btnPtr = JNFrameGetCommandBarButton(x, y)
                if (GetCommandBarButtonHotkey(btnPtr) == hotkey) then
                    return btnPtr
                endif

                set x = x + 1
            endloop

            set y = y + 1
        endloop

        return 0
    endfunction

    private function CancelButtonIsExists takes nothing returns boolean
        local integer btnPtr = JNFrameGetCommandBarButton(3, 2)
        if (GetCommandBarButtonData(btnPtr) != 0) then
            return (GetCommandBarButtonAbilityId(btnPtr) == 0)
        endif
        return false
    endfunction

    private function ModalIsOpen takes nothing returns boolean
        return (JNMemoryGetInteger(JNGetGameUI() + 0x1BC) != 0)
    endfunction

    private struct StringBuffer
        private string buffer
        private integer size

        public static method create takes string s returns thistype
            local thistype this = thistype.allocate()
            set this.buffer = s
            set this.size = StringLength(s)
            return this
        endmethod

        public method writeInteger takes integer val returns nothing
            set this.buffer = this.buffer + I2S(val) + " "
        endmethod

        public method writeReal takes real val returns nothing
            set this.buffer = this.buffer + R2S(val) + " "
        endmethod

        public method nextInteger takes nothing returns integer
            local integer ret = S2I(this.buffer)
            local integer retSize = StringLength(I2S(ret))

            set this.buffer = SubString(this.buffer, retSize + 1, this.size)
            set this.size = this.size - (retSize + 1)

            return ret
        endmethod

        public method nextReal takes nothing returns real
            local real ret = S2R(this.buffer)
            local integer retSize = StringLength(R2S(ret))

            set this.buffer = SubString(this.buffer, retSize + 1, this.size)
            set this.size = this.size - (retSize + 1)
            return ret
        endmethod

        public method toString takes nothing returns string
            return this.buffer
        endmethod
    endstruct

    private function HandleMessage takes nothing returns nothing
        local string message = JNGetTriggerSyncData()
        local StringBuffer sb = StringBuffer.create(message)

        local integer orderType = sb.nextInteger()
        local unit whichUnit
        local integer orderId
        local unit target
        local real targetX
        local real targetY

        if (orderType == ORDER_TYPE_POINT) then
            set whichUnit = I2U(sb.nextInteger())
            set orderId = sb.nextInteger()
            set targetX = sb.nextReal()
            set targetY = sb.nextReal()
            call IssuePointOrderById(whichUnit, orderId, targetX, targetY)
        elseif (orderType == ORDER_TYPE_TARGET) then
            set whichUnit = I2U(sb.nextInteger())
            set orderId = sb.nextInteger()
            set target = I2U(sb.nextInteger())
            call IssueTargetOrderById(whichUnit, orderId, target)
        endif

        call sb.destroy()
        set whichUnit = null
        set target = null
    endfunction

    private function SendPointOrderMessage takes unit whichUnit, integer orderId, real targetX, real targetY returns nothing
        local StringBuffer sb = StringBuffer.create("")

        call sb.writeInteger(ORDER_TYPE_POINT)
        call sb.writeInteger(GetHandleId(whichUnit))
        call sb.writeInteger(orderId)
        call sb.writeReal(targetX)
        call sb.writeReal(targetY)
        call JNSendSyncData(SYNC_PREFIX, sb.toString())

        call sb.destroy()
    endfunction

    private function SendTargetOrderMessage takes unit whichUnit, integer orderId, unit target returns nothing
        local StringBuffer sb = StringBuffer.create("")

        call sb.writeInteger(ORDER_TYPE_TARGET)
        call sb.writeInteger(GetHandleId(whichUnit))
        call sb.writeInteger(orderId)
        call sb.writeInteger(GetHandleId(target))
        call JNSendSyncData(SYNC_PREFIX, sb.toString())

        call sb.destroy()
    endfunction

    private function IssueSmartCastOrder takes unit whichUnit, integer btnPtr returns boolean
        local integer abilityId = GetCommandBarButtonAbilityId(btnPtr)
        local integer orderId
        local integer orderType
        local unit target
        local boolean targetingFails = false

        if (GetUnitAbilityLevel(whichUnit, abilityId) == 0) then
            return false
        endif

        set orderId = GetCommandBarButtonOrderId(btnPtr)
        set orderType = GetCommandBarButtonOrderType(btnPtr)

        if (JNBitAnd(orderType, ORDER_TYPE_TARGET) == ORDER_TYPE_TARGET) then
            set target = JNGetMouseFocusUnit()
            if (target != null) then
                call SendTargetOrderMessage(whichUnit, orderId, target)
                set target = null
                return true
            else
                set targetingFails = true
            endif
        endif

        if (JNBitAnd(orderType, ORDER_TYPE_POINT) == ORDER_TYPE_POINT) then
            call SendPointOrderMessage(whichUnit, orderId, DzGetMouseTerrainX(), DzGetMouseTerrainY())
            return true
        endif

        if (ignoreWhenTargetingFails and targetingFails) then
            return true
        endif

        return false
    endfunction

    private function CommandButtonIsSmartCastable takes integer btnPtr returns boolean
        local integer abilityId = GetCommandBarButtonAbilityId(btnPtr)
        local integer triggerType = GetAbilityTriggerType(abilityId)
        if (triggerType == TRIGGER_TYPE_NONE) then
            return false
        elseif (triggerType == TRIGGER_TYPE_ALWAYS) then
            return true
        elseif (triggerType == TRIGGER_TYPE_SHIFT_DOWN) then
            return DzIsKeyDown(JN_OSKEY_SHIFT)
        elseif (triggerType == TRIGGER_TYPE_SHIFT_UP) then
            return not DzIsKeyDown(JN_OSKEY_SHIFT)
        endif
        return false
    endfunction

    private function CountSelectedUnit takes nothing returns integer
        local unit selectedUnit
        local integer n = 0
        call GroupEnumUnitsSelected(selectionGroup, GetLocalPlayer(), null)
        loop
            set selectedUnit = FirstOfGroup(selectionGroup)
            exitwhen (selectedUnit == null)
            set n = n + 1
            call GroupRemoveUnit(selectionGroup, selectedUnit)
        endloop
        return n
    endfunction

    private function HandleKeyPress takes nothing returns nothing
        local integer keycode
        local string keychar
        local unit selectedUnit
        local integer btnPtr
        local integer abilityId
        local integer triggerType
        local boolean casted

        if (ChatInputFrameIsVisible() or ModalIsOpen() or CancelButtonIsExists()) then
            return
        endif

        set keycode = JNGetTriggerKey()
        set btnPtr = GetCommandBarButtonByHotkey(keycode)

        if (not CommandButtonIsSmartCastable(btnPtr)) then
            return
        endif
        if (GetCommandBarButtonState(btnPtr) != COMMAND_BUTTON_STATE_READY) then
            return
        endif

        if ((not multiUnitSmartCastEnabled) and (CountSelectedUnit() > 1)) then
            return
        endif

        set casted = false
        call GroupEnumUnitsSelected(selectionGroup, GetLocalPlayer(), null)
        loop
            set selectedUnit = FirstOfGroup(selectionGroup)
            exitwhen (selectedUnit == null)

            if (IssueSmartCastOrder(selectedUnit, btnPtr)) then
                set casted = true
            endif

            call GroupRemoveUnit(selectionGroup, selectedUnit)
        endloop

        if (casted) then
            set removingTargetingUI = true
            call EnableUserControl(false)
        endif
    endfunction

    private function HandleTargetingUI takes nothing returns nothing
        if (removingTargetingUI) then
            call EnableUserControl(true)
            set removingTargetingUI = false
        endif
    endfunction

    private function InitHandlers takes nothing returns nothing
        set keyPressHandler = CreateTrigger()

        set syncHandler = CreateTrigger()
        call JNTriggerRegisterSyncData(syncHandler, SYNC_PREFIX, false)
        call TriggerAddAction(syncHandler, function HandleMessage)

        set targetingUIHandler = CreateTimer()
        call TimerStart(targetingUIHandler, 0.01, true, function HandleTargetingUI)
    endfunction

    private function RegisterKey takes integer keycode returns nothing
        call DzTriggerRegisterKeyEventByCode(keyPressHandler, keycode, 1, false, function HandleKeyPress)
    endfunction

    private function RegisterAlphabetKeys takes nothing returns nothing
        local string alphabets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        local integer keycode
        local string keychar
        local integer i = 0
        local integer n = StringLength(alphabets)
        loop
            exitwhen (i >= n)

            set keycode = JN_OSKEY_A + i
            call RegisterKey(keycode)

            set i = i + 1
        endloop
    endfunction

    private function RegisterKeys takes nothing returns nothing
        call RegisterAlphabetKeys()
    endfunction

    private function Init takes nothing returns nothing
        call InitHandlers()
        call RegisterKeys()
    endfunction
endlibrary
