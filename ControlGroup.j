/*
 * ControlGroup v2021.08.14
 *
 * 주의사항:
 *   게임 시작 후에 정상 작동 합니다.
 *
 * 함수:
 *   function SelectControlGroupBJ takes player whichPlayer, integer convertedControlGroupId returns nothing
 *     특정 플레이어에게 지정된 부대를 선택합니다.
 *     whichPlayer: 선택할 플레이어
 *     convertedControlGroupId: 선택할 부대 번호 (1~10)
 *   function AssignControlGroupBySelectionBJ takes player whichPlayer, integer convertedControlGroupId returns nothing
 *     특정 플레이어에게 선택된 유닛에 부대를 지정합니다.
 *     whichPlayer: 지정할 플레이어
 *     convertedControlGroupId: 지정할 부대 번호 (1~10)
 *   function AssignControlGroupByGroupBJ takes player whichPlayer, integer convertedControlGroupId, group whichGroup returns nothing
 *     특정 플레이어에게 특정 유닛 그룹의 유닛들로 부대를 지정합니다.
 *     whichPlayer: 지정할 플레이어
 *     convertedControlGroupId: 지정할 부대 번호 (1~10)
 *     whichGroup: 부대 지정할 유닛 그룹
 *   function AssignControlGroupByUnitBJ takes player whichPlayer, integer convertedControlGroupId, unit whichUnit returns nothing
 *     특정 플레이어에게 단일 유닛으로 부대를 지정합니다.
 *     whichPlayer: 지정할 플레이어
 *     convertedControlGroupId: 지정할 부대 번호 (1~10)
 *     whichUnit: 부대 지정할 유닛
 */

//! import "DzAPIHardware.j"

library ControlGroup requires DzAPIHardware, MemoryLib
    globals
        private constant integer CONTROL_MODE_NONE = 0
        private constant integer CONTROL_MODE_SELECT = 1
        private constant integer CONTROL_MODE_ASSIGN = 2

        private group tempGroup = CreateGroup()
    endglobals

    //! runtextmacro MemoryLib_DefineMemoryBlock("private", "MemoryBlock", "ControlGroup__MemoryBlock", "4 * 20")

    private function HotkeyOfControlGroup takes integer controlGroupId returns integer
        if ((controlGroupId >= 0) or (controlGroupId <= 9)) then
            if (controlGroupId == 9) then
                return JN_OSKEY_0
            else
                return JN_OSKEY_1 + controlGroupId
            endif
        endif
        return 0
    endfunction

    private function ConvertedControlGroupId takes integer convertedControlGroupId returns integer
        if ((convertedControlGroupId >= 1) or (convertedControlGroupId <= 10)) then
            return convertedControlGroupId - 1
        endif
        return 0
    endfunction

    private function ForceControlMode takes integer mode returns nothing
        local BytePtr statement = BytePtr(pGameDll + 0x3C7D39)
        if (mode == CONTROL_MODE_SELECT) then
            // Game.dll+3C7D39 - E9 22010000           - jmp Game.dll+3C7E60
            set statement[0] = 0xE9
            set statement[1] = 0x22
            set statement[2] = 0x01
            set statement[3] = 0x00
            set statement[4] = 0x00
            set statement[5] = 0x90  // nop
        elseif (mode == CONTROL_MODE_ASSIGN) then
            // nop
            set statement[0] = 0x90
            set statement[1] = 0x90
            set statement[2] = 0x90
            set statement[3] = 0x90
            set statement[4] = 0x90
            set statement[5] = 0x90
        else
            // Game.dll+3C7D39 - 0F84 21010000         - je Game.dll+3C7E60
            set statement[0] = 0x0F
            set statement[1] = 0x84
            set statement[2] = 0x21
            set statement[3] = 0x01
            set statement[4] = 0x00
            set statement[5] = 0x00
        endif
    endfunction

    private function KeyDownEvent takes integer keycode returns Ptr
        local Ptr pBlock = MemoryBlock.pHead
        set IntPtr(pBlock)[0] = pGameDll + 0xA73538
        set IntPtr(pBlock)[1] = 0
        set IntPtr(pBlock)[2] = 0x40060064
        set IntPtr(pBlock)[3] = 0
        set IntPtr(pBlock)[4] = keycode
        set IntPtr(pBlock)[10] = 0
        return pBlock
    endfunction

    function SelectControlGroup takes integer controlGroupId returns nothing
        local GameUI gameUI = GameUI.getInstance()
        local integer numkey = HotkeyOfControlGroup(controlGroupId)

        call ForceControlMode(CONTROL_MODE_SELECT)
        call gameUI.handleEvent(KeyDownEvent(numkey))
        call ForceControlMode(CONTROL_MODE_NONE)
    endfunction

    function GroupEnumUnitsLocalControlGroup takes group whichGroup, integer controlGroupId, boolexpr filter  returns nothing
        local group oldSelection = tempGroup
        call GroupEnumUnitsSelected(oldSelection, GetLocalPlayer(), null)

        call SelectControlGroup(controlGroupId)
        call GroupEnumUnitsSelected(whichGroup, GetLocalPlayer(), filter)

        call SelectGroupBJ(oldSelection)
        set oldSelection = null
    endfunction

    function AssignControlGroupBySelection takes integer controlGroupId returns nothing
        local GameUI gameUI = GameUI.getInstance()
        local integer numkey = HotkeyOfControlGroup(controlGroupId)

        call ForceControlMode(CONTROL_MODE_ASSIGN)
        call gameUI.handleEvent(KeyDownEvent(numkey))
        call ForceControlMode(CONTROL_MODE_NONE)
    endfunction

    function AssignControlGroupByGroup takes integer controlGroupId, group whichGroup returns nothing
        local group oldSelection = tempGroup

        if (whichGroup == null) then
            return
        endif

        call GroupEnumUnitsSelected(oldSelection, GetLocalPlayer(), null)

        call SelectGroupBJ(whichGroup)
        call AssignControlGroupBySelection(controlGroupId)

        call SelectGroupBJ(oldSelection)
        set oldSelection = null
    endfunction

    function AssignControlGroupByUnit takes integer controlGroupId, unit whichUnit returns nothing
        local group oldSelection = tempGroup

        if (whichUnit == null) then
            return
        endif

        call GroupEnumUnitsSelected(oldSelection, GetLocalPlayer(), null)

        call SelectUnitSingle(whichUnit)
        call AssignControlGroupBySelection(controlGroupId)

        call SelectGroupBJ(oldSelection)
        set oldSelection = null
    endfunction

    function SelectControlGroupBJ takes player whichPlayer, integer convertedControlGroupId returns nothing
        if (GetLocalPlayer() == whichPlayer) then
            call SelectControlGroup(ConvertedControlGroupId(convertedControlGroupId))
        endif
    endfunction

    function AssignControlGroupBySelectionBJ takes player whichPlayer, integer convertedControlGroupId returns nothing
        if (GetLocalPlayer() == whichPlayer) then
            call AssignControlGroupBySelection(ConvertedControlGroupId(convertedControlGroupId))
        endif
    endfunction

    function AssignControlGroupByGroupBJ takes player whichPlayer, integer convertedControlGroupId, group whichGroup returns nothing
        if (GetLocalPlayer() == whichPlayer) then
            call AssignControlGroupByGroup(ConvertedControlGroupId(convertedControlGroupId), whichGroup)
        endif
    endfunction

    function AssignControlGroupByUnitBJ takes player whichPlayer, integer convertedControlGroupId, unit whichUnit returns nothing
        if (GetLocalPlayer() == whichPlayer) then
            call AssignControlGroupByUnit(ConvertedControlGroupId(convertedControlGroupId), whichUnit)
        endif
    endfunction
endlibrary
