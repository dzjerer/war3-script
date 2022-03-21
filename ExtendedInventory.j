/*
 * ExtendedInventory (v0.0)
 * 유닛이 인벤토리 능력을 여러 개 가졌을 때에도 작동하는 인벤토리 관련 함수들을 제공합니다.
 * 유닛의 아이템 최대 한도를 늘릴 때 사용합니다.
 *
 * 함수:
 *   function UnitInventorySizeEx takes unit whichUnit returns integer
 *     유닛의 인벤토리 크기
 *
 *   function UnitHasItemEx takes unit whichUnit, item whichItem returns boolean
 *     유닛의 아이템 소유 여부
 *
 *   function UnitHasItemOfTypeEx takes unit whichUnit, integer itemId returns boolean
 *     유닛의 아이템 타입 소유 여부
 *
 *   function GetInventoryIndexOfItemEx takes unit whichUnit, item whichItem, integer fromIndex returns integer
 *     유닛이 소유한 아이템의 슬롯 위치 (못 찾으면 -1을 반환)
 *     fromIndex: 탐색 시작 위치
 *
 *   function GetInventoryIndexOfItemTypeEx takes unit whichUnit, integer itemId, integer fromIndex returns integer
 *     유닛이 소유한 아이템 타입의 슬롯 위치 (못 찾으면 -1을 반환)
 *     itemId: 아이템 타입 코드 (0 이라면, 빈 슬롯을 찾음)
 *     fromIndex: 탐색 시작 위치
 *
 *   function GetInventoryLastIndexOfItemEx takes unit whichUnit, item whichItem, integer fromIndex returns integer
 *     유닛이 소유한 아이템의 슬롯 위치를 역순으로 탐색 (못 찾으면 -1을 반환)
 *     fromIndex: 탐색 시작 위치
 *
 *   function GetInventoryLastIndexOfItemTypeEx takes unit whichUnit, integer itemId, integer fromIndex returns integer
 *     유닛이 소유한 아이템 타입의 슬롯 위치를 역순으로 탐색 (못 찾으면 -1을 반환)
 *     itemId: 아이템 타입 코드 (0 이라면, 빈 슬롯을 찾음)
 *     fromIndex: 탐색 시작 위치
 *
 *   function UnitItemInSlotEx takes unit whichUnit, integer itemSlot returns item
 *     유닛의 특정 슬롯의 아이템
 *
 *   function UnitAddItemEx takes unit whichUnit, item whichItem returns boolean
 *     유닛에게 아이템을 줍니다.
 *     슬롯의 앞부터 채웁니다.
 *     ※ 주의: 이미 누군가가 들고있는 아이템을 주면 버그가 발생합니다. 드랍된 아이템에만 사용하세요.
 *
 *   function UnitAddItemPickupOrderEx takes unit whichUnit, item whichItem returns boolean
 *     유닛에게 아이템을 줍니다.
 *     우클릭으로 줍는 것과 같은 순서로 채웁니다.
 *     ※ 주의: 이미 누군가가 들고있는 아이템을 주면 버그가 발생합니다. 드랍된 아이템에만 사용하세요.
 *
 *   function UnitAddItemSlotEx takes unit whichUnit, item whichItem, integer itemSlot returns boolean
 *     유닛에게 아이템을 특정 슬롯에 줍니다.
 *     ※ 주의: 이미 누군가가 들고있는 아이템을 주면 버그가 발생합니다. 드랍된 아이템에만 사용하세요.
 *
 *   function UnitRemoveItemEx takes unit whichUnit, item whichItem returns boolean
 *     유닛에게서 아이템을 발치에 떨어뜨립니다.
 *
 *   function UnitRemoveItemFromSlotEx takes unit whichUnit, integer itemSlot returns nothing
 *     유닛에게서 특정 슬롯의 아이템을 발치에 떨어뜨립니다.
 *
 *   function UnitDropItemSlotEx takes unit whichUnit, item whichItem, integer itemSlot returns boolean
 *     유닛이 소유한 아이템을 특정 슬롯으로 이동합니다.
 *
 *   function UnitSwapItemSlotEx takes unit whichUnit, item itemSlotA, integer itemSlotB returns boolean
 *     유닛이 소유한 아이템을 특정 슬롯으로 이동합니다.
 *
 *   function SaveItemHandlesInInventoryEx takes hashtable table, integer parentKey, unit whichUnit returns nothing
 *     유닛의 모든 슬롯의 아이템들을 해시 테이블에 저장합니다.
 *     기존에 table의 parentKey에 저장된 내용은 초기화됩니다.
 *     - LoadInteger(table, parentKey, 0): 인벤토리 크기
 *     - LoadItemHandle(table, parentKey, i): i번째 슬롯의 아이템
 *     모든 아이템을 UI에 한 번에 표시할 때 유용합니다.
 */
library ExtendedInventory requires AbilityInventory

    private struct Stack extends array
        public static integer array e
        public static integer top = 0

        public static method operator[] takes integer index returns integer
            return thistype.e[index]
        endmethod

        public static method operator[]= takes integer index, integer value returns nothing
            set thistype.e[index] = value
        endmethod
    endstruct

    private struct InventoryIndex
        public unit owner
        public integer itemSlot
        public AbilityInventory inventory
        public integer index
    endstruct


    private function GetInventoryIndexOfItem takes AbilityInventory inventory, item whichItem, integer start, integer end returns integer
        local integer i
        set i = start
        loop
            exitwhen (i >= end)
            if (inventory.getItemInSlot(i) == whichItem) then
                return i
            endif
            set i = i + 1
        endloop
        return -1
    endfunction

    private function GetInventoryIndexOfItemType takes AbilityInventory inventory, integer itemId, integer start, integer end returns integer
        local integer i
        local item indexItem

        set i = start
        loop
            exitwhen (i >= end)
            set indexItem = inventory.getItemInSlot(i)
            if (GetItemTypeId(indexItem) == itemId) then
                set indexItem = null
                return i
            endif
            set i = i + 1
        endloop

        set indexItem = null
        return -1
    endfunction

    private function GetInventoryLastIndexOfItem takes AbilityInventory inventory, item whichItem, integer fromIndex returns integer
        local integer i
        set i = fromIndex
        loop
            exitwhen (i < 0)
            if (inventory.getItemInSlot(i) == whichItem) then
                return i
            endif
            set i = i - 1
        endloop
        return -1
    endfunction

    private function GetInventoryLastIndexOfItemType takes AbilityInventory inventory, integer itemId, integer fromIndex returns integer
        local integer i
        local item indexItem

        set i = fromIndex
        loop
            exitwhen (i < 0)
            set indexItem = inventory.getItemInSlot(i)
            if (GetItemTypeId(indexItem) == itemId) then
                set indexItem = null
                return i
            endif
            set i = i - 1
        endloop

        set indexItem = null
        return -1
    endfunction

    private function FindInventoryIndexOfItem takes unit whichUnit, item whichItem, integer fromIndex returns InventoryIndex
        local InventoryIndex invIndex
        local AbilityInventory inventory
        local integer size
        local integer subIndex
        local integer offset = 0

        if (whichUnit == null) or (whichItem == null) then
            return 0
        endif

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)
            set size = inventory.getSize()
            if (offset + size > fromIndex) and inventory.hasItem(whichItem) then
                set subIndex = GetInventoryIndexOfItem(inventory, whichItem, IMaxBJ(fromIndex - offset, 0), size)
                if (subIndex != -1) then
                    set invIndex = InventoryIndex.create()
                    set invIndex.owner = whichUnit
                    set invIndex.itemSlot = offset + subIndex
                    set invIndex.inventory = inventory
                    set invIndex.index = subIndex
                    return invIndex
                endif
            endif
            set offset = offset + size
            set inventory = inventory.next()
        endloop

        return 0
    endfunction

    private function FindInventoryIndexOfItemType takes unit whichUnit, integer itemId, integer fromIndex returns InventoryIndex
        local InventoryIndex invIndex
        local AbilityInventory inventory
        local integer size
        local integer subIndex
        local integer offset = 0

        if (whichUnit == null) then
            return 0
        endif

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)
            set size = inventory.getSize()
            if (offset + size > fromIndex) then
                set subIndex = GetInventoryIndexOfItemType(inventory, itemId, IMaxBJ(fromIndex - offset, 0), size)
                if (subIndex != -1) then
                    set invIndex = InventoryIndex.create()
                    set invIndex.owner = whichUnit
                    set invIndex.itemSlot = offset + subIndex
                    set invIndex.inventory = inventory
                    set invIndex.index = subIndex
                    return invIndex
                endif
            endif
            set offset = offset + size
            set inventory = inventory.next()
        endloop

        return 0
    endfunction

    private function FindInventoryLastIndexOfItem takes unit whichUnit, item whichItem, integer fromIndex returns InventoryIndex
        local InventoryIndex invIndex
        local AbilityInventory inventory
        local integer size
        local integer subIndex
        local integer offset = 0
        local integer oldTop = Stack.top

        if (whichUnit == null) or (whichItem == null) then
            return 0
        endif

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)
            set Stack[Stack.top] = inventory
            set Stack.top = Stack.top + 1
            set offset = offset + inventory.getSize()
            set inventory = inventory.next()
        endloop

        loop
            exitwhen (Stack.top == oldTop)
            set Stack.top = Stack.top - 1
            set inventory = Stack[Stack.top]
            set size = inventory.getSize()
            set offset = offset - size

            if (offset <= fromIndex) and inventory.hasItem(whichItem) then
                set subIndex = GetInventoryLastIndexOfItem(inventory, whichItem, IMinBJ(fromIndex - offset, size - 1))
                if (subIndex != -1) then
                    set invIndex = InventoryIndex.create()
                    set invIndex.owner = whichUnit
                    set invIndex.itemSlot = offset + subIndex
                    set invIndex.inventory = inventory
                    set invIndex.index = subIndex

                    set Stack.top = oldTop
                    return invIndex
                endif
            endif
        endloop

        set Stack.top = oldTop
        return 0
    endfunction

    private function FindInventoryLastIndexOfItemType takes unit whichUnit, integer itemId, integer fromIndex returns InventoryIndex
        local InventoryIndex invIndex
        local AbilityInventory inventory
        local integer size
        local integer subIndex
        local integer offset = 0
        local integer oldTop = Stack.top

        if (whichUnit == null) then
            return 0
        endif

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)
            set Stack[Stack.top] = inventory
            set Stack.top = Stack.top + 1
            set offset = offset + inventory.getSize()
            set inventory = inventory.next()
        endloop

        loop
            exitwhen (Stack.top == oldTop)
            set Stack.top = Stack.top - 1
            set inventory = Stack[Stack.top]
            set size = inventory.getSize()
            set offset = offset - size

            if (offset <= fromIndex)then
                set subIndex = GetInventoryLastIndexOfItemType(inventory, itemId, IMinBJ(fromIndex - offset, size - 1))
                if (subIndex != -1) then
                    set invIndex = InventoryIndex.create()
                    set invIndex.owner = whichUnit
                    set invIndex.itemSlot = offset + subIndex
                    set invIndex.inventory = inventory
                    set invIndex.index = subIndex

                    set Stack.top = oldTop
                    return invIndex
                endif
            endif
        endloop

        set Stack.top = oldTop
        return 0
    endfunction

    private function FindInventoryIndexOfSlot takes unit whichUnit, integer itemSlot returns InventoryIndex
        local InventoryIndex invIndex
        local AbilityInventory inventory
        local integer offset = 0
        local integer size

        if (whichUnit == null) or (itemSlot < 0) then
            return 0
        endif

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)

            set size = inventory.getSize()
            if (offset + size > itemSlot) then
                set invIndex = InventoryIndex.create()
                set invIndex.owner = whichUnit
                set invIndex.itemSlot = itemSlot
                set invIndex.inventory = inventory
                set invIndex.index = itemSlot - offset
                return invIndex
            endif
            set offset = offset + size

            set inventory = inventory.next()
        endloop

        return 0
    endfunction


    function UnitInventorySizeEx takes unit whichUnit returns integer
        local integer totalSize = 0
        local AbilityInventory inventory

        if (whichUnit == null) then
            return 0
        endif

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)
            set totalSize = totalSize + inventory.getSize()
            set inventory = inventory.next()
        endloop

        return totalSize
    endfunction

    function UnitHasItemEx takes unit whichUnit, item whichItem returns boolean
        local InventoryIndex invIndex = FindInventoryIndexOfItem(whichUnit, whichItem, 0)
        if (invIndex == 0) then
            return false
        endif
        call invIndex.destroy()
        return true
    endfunction

    function UnitHasItemOfTypeEx takes unit whichUnit, integer itemId returns boolean
        local InventoryIndex invIndex = FindInventoryIndexOfItemType(whichUnit, itemId, 0)
        if (invIndex == 0) then
            return false
        endif
        call invIndex.destroy()
        return true
    endfunction

    function GetInventoryIndexOfItemEx takes unit whichUnit, item whichItem, integer fromIndex returns integer
        local InventoryIndex invIndex = FindInventoryIndexOfItem(whichUnit, whichItem, fromIndex)
        local integer ret
        if (invIndex == 0) then
            return -1
        endif
        set ret = invIndex.itemSlot
        call invIndex.destroy()
        return ret
    endfunction

    function GetInventoryIndexOfItemTypeEx takes unit whichUnit, integer itemId, integer fromIndex returns integer
        local InventoryIndex invIndex = FindInventoryIndexOfItemType(whichUnit, itemId, fromIndex)
        local integer ret
        if (invIndex == 0) then
            return -1
        endif
        set ret = invIndex.itemSlot
        call invIndex.destroy()
        return ret
    endfunction

    function GetInventoryLastIndexOfItemEx takes unit whichUnit, item whichItem, integer fromIndex returns integer
        local InventoryIndex invIndex = FindInventoryLastIndexOfItem(whichUnit, whichItem, fromIndex)
        local integer ret
        if (invIndex == 0) then
            return -1
        endif
        set ret = invIndex.itemSlot
        call invIndex.destroy()
        return ret
    endfunction

    function GetInventoryLastIndexOfItemTypeEx takes unit whichUnit, integer itemId, integer fromIndex returns integer
        local InventoryIndex invIndex = FindInventoryLastIndexOfItemType(whichUnit, itemId, fromIndex)
        local integer ret
        if (invIndex == 0) then
            return -1
        endif
        set ret = invIndex.itemSlot
        call invIndex.destroy()
        return ret
    endfunction

    function UnitItemInSlotEx takes unit whichUnit, integer itemSlot returns item
        local InventoryIndex invIndex = FindInventoryIndexOfSlot(whichUnit, itemSlot)
        if (invIndex == 0) then
            return null
        endif
        return invIndex.inventory.getItemInSlot(invIndex.index)
    endfunction

    function UnitAddItemEx takes unit whichUnit, item whichItem returns boolean
        local AbilityInventory inventory

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)

            if (inventory.addItem(whichItem, false)) then
                return true
            endif

            set inventory = inventory.next()
        endloop

        return false
    endfunction

    function UnitAddItemPickupOrderEx takes unit whichUnit, item whichItem returns boolean
        local AbilityInventory inventory
        local integer oldTop = Stack.top

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)

            set Stack[Stack.top] = inventory
            set Stack.top = Stack.top + 1

            set inventory = inventory.next()
        endloop

        loop
            exitwhen (Stack.top == oldTop)
            set Stack.top = Stack.top - 1
            set inventory = Stack[Stack.top]

            if (inventory.addItem(whichItem, false)) then
                set Stack.top = oldTop
                return true
            endif
        endloop

        set Stack.top = oldTop
        return false
    endfunction

    function UnitAddItemSlotEx takes unit whichUnit, item whichItem, integer itemSlot returns boolean
        local AbilityInventory inventory
        local integer size
        local integer offset = 0

        if (itemSlot < 0) then
            return false
        endif

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)

            set size = inventory.getSize()
            if (offset + size > itemSlot) then
                return inventory.addItemInSlot(whichItem, itemSlot - offset, false)
            else
                set offset = offset + size
            endif

            set inventory = inventory.next()
        endloop

        return false
    endfunction

    function UnitRemoveItemEx takes unit whichUnit, item whichItem returns boolean
        local AbilityInventory inventory

        if (whichUnit == null) or (whichItem == null) then
            return false
        endif

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)
            if inventory.removeItem(whichItem) then
                call SetItemPosition(whichItem, GetUnitX(whichUnit), GetUnitY(whichUnit))
                return true
            endif
            set inventory = inventory.next()
        endloop

        return false
    endfunction

    function UnitRemoveItemFromSlotEx takes unit whichUnit, integer itemSlot returns nothing
        call UnitRemoveItemEx(whichUnit, UnitItemInSlotEx(whichUnit, itemSlot))
    endfunction

    function UnitDropItemSlotEx takes unit whichUnit, item whichItem, integer itemSlot returns boolean
        local InventoryIndex srcIndex = FindInventoryIndexOfItem(whichUnit, whichItem, 0)
        local InventoryIndex dstIndex
        local item srcItem
        local item dstItem
        
        if (srcIndex == 0) then
            return false
        endif
        if (srcIndex.itemSlot == itemSlot) then
            call srcIndex.destroy()
            return true
        endif

        set dstIndex = FindInventoryIndexOfSlot(whichUnit, itemSlot)
        if (dstIndex == 0) then
            call srcIndex.destroy()
            return false
        endif

        set srcItem = srcIndex.inventory.getItemInSlot(srcIndex.index)
        set dstItem = dstIndex.inventory.getItemInSlot(dstIndex.index)
        call srcIndex.inventory.swapSlot(srcIndex.index, dstIndex.inventory, dstIndex.index)

        call srcIndex.destroy()
        call dstIndex.destroy()
        set srcItem = null
        set dstItem = null
        return true
    endfunction

    function UnitSwapItemSlotEx takes unit whichUnit, integer itemSlotA, integer itemSlotB returns boolean
        local InventoryIndex srcIndex = FindInventoryIndexOfSlot(whichUnit, itemSlotA)
        local InventoryIndex dstIndex = FindInventoryIndexOfSlot(whichUnit, itemSlotB)
        local boolean swapped = false
        
        if (srcIndex != 0) and (dstIndex != 0) then
            if (srcIndex.itemSlot != dstIndex.itemSlot) then
                call srcIndex.inventory.swapSlot(srcIndex.index, dstIndex.inventory, dstIndex.index)
            endif
            set swapped = true
        endif

        if (srcIndex != 0) then
            call srcIndex.destroy()
        endif
        if (dstIndex != 0) then
            call dstIndex.destroy()
        endif
        return swapped
    endfunction

    function SaveItemHandlesInInventoryEx takes hashtable table, integer parentKey, unit whichUnit returns nothing
        local AbilityInventory inventory
        local integer offset = 0
        local integer size
        local integer itemSlot
        local integer i

        call FlushChildHashtable(table, parentKey)

        set inventory = AbilityInventory.getFirstOf(whichUnit)
        loop
            exitwhen (inventory == 0)

            set size = inventory.getSize()
            set i = 0
            loop
                exitwhen (i >= size)
                
                set itemSlot = offset + i
                call SaveItemHandle(table, parentKey, itemSlot, inventory.getItemInSlot(i))
                
                set i = i + 1
            endloop
            set offset = offset + size

            set inventory = inventory.next()
        endloop
        
        set size = offset
        call SaveInteger(table, parentKey, 0, size)
    endfunction


    private function Init takes nothing returns nothing
    endfunction
endlibrary


/*
 * AbilityInventory (v0.0)
 * 인벤토리 능력 내부 클래스 Wrapper
 */
library AbilityInventory initializer Init requires /*
    */ MemoryLib /* https://github.com/heoh/war3-memory-lib (>= v0.1-alpha) */

    globals
        private hashtable ht = InitHashtable()
        private Ptr pGameWar3
    endglobals

    private function B2I takes boolean b returns integer
        if b then
            return 1
        else
            return 0
        endif
    endfunction

    private function GetItemByHandleId takes integer handleId returns item
        call SaveFogStateHandle(ht, 0, 0, ConvertFogState(handleId))
        return LoadItemHandle(ht, 0, 0)
    endfunction

    private function sub_8AE90 takes integer this returns integer
        local Ptr pFunc = pGameDll + 0x8AE90
        call SaveStr(JNProc_ht, JNProc_key, 0, "(I)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_2135F0 takes integer this returns integer
        local Ptr pFunc = pGameDll + 0x2135F0
        call SaveStr(JNProc_ht, JNProc_key, 0, "(I)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_21FEA0 takes integer this returns integer
        local Ptr pFunc = pGameDll + 0x21FEA0
        call SaveStr(JNProc_ht, JNProc_key, 0, "(I)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_2217A0 takes integer this returns integer
        local Ptr pFunc = pGameDll + 0x2217A0
        call SaveStr(JNProc_ht, JNProc_key, 0, "(I)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_256990 takes integer this, integer a2 returns integer
        local Ptr pFunc = pGameDll + 0x256990
        call SaveStr(JNProc_ht, JNProc_key, 0, "(II)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_2B52E0 takes integer this, integer a2, integer a3 returns integer
        local Ptr pFunc = pGameDll + 0x2B52E0
        call SaveStr(JNProc_ht, JNProc_key, 0, "(III)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        call SaveInteger(JNProc_ht, JNProc_key, 3, a3)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_576090 takes integer this, integer a2, boolean a3 returns boolean
        local Ptr pFunc = pGameDll + 0x576090
        call SaveStr(JNProc_ht, JNProc_key, 0, "(IIB)B")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        call SaveBoolean(JNProc_ht, JNProc_key, 3, a3)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadBoolean(JNProc_ht, JNProc_key, 0)
        endif
        return false
    endfunction

    private function sub_576100 takes integer this, integer a2, integer a3, boolean a4 returns boolean
        local Ptr pFunc = pGameDll + 0x576100
        call SaveStr(JNProc_ht, JNProc_key, 0, "(IIIB)B")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        call SaveInteger(JNProc_ht, JNProc_key, 3, a3)
        call SaveBoolean(JNProc_ht, JNProc_key, 4, a4)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadBoolean(JNProc_ht, JNProc_key, 0)
        endif
        return false
    endfunction

    private function sub_57CE20 takes integer this, integer a2 returns boolean
        local Ptr pFunc = pGameDll + 0x57CE20
        call SaveStr(JNProc_ht, JNProc_key, 0, "(II)B")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadBoolean(JNProc_ht, JNProc_key, 0)
        endif
        return false
    endfunction

    private function sub_58CA70 takes integer this returns integer
        local Ptr pFunc = pGameDll + 0x58CA70
        call SaveStr(JNProc_ht, JNProc_key, 0, "(I)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_58D480 takes integer this, integer a2 returns integer
        local Ptr pFunc = pGameDll + 0x58D480
        call SaveStr(JNProc_ht, JNProc_key, 0, "(II)I")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadInteger(JNProc_ht, JNProc_key, 0)
        endif
        return 0
    endfunction

    private function sub_59A900 takes integer this, integer a2 returns boolean
        local Ptr pFunc = pGameDll + 0x59A900
        call SaveStr(JNProc_ht, JNProc_key, 0, "(II)B")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call SaveInteger(JNProc_ht, JNProc_key, 2, a2)
        if (JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)) then
            return LoadBoolean(JNProc_ht, JNProc_key, 0)
        endif
        return false
    endfunction

    private function sub_6C7EF0 takes integer this returns nothing
        local Ptr pFunc = pGameDll + 0x6C7EF0
        call SaveStr(JNProc_ht, JNProc_key, 0, "(I)V")
        call SaveInteger(JNProc_ht, JNProc_key, 1, this)
        call JNProcCall(JNProc__thiscall, pFunc, JNProc_ht)
    endfunction

    private function GetUnitPtr takes unit whichUnit returns Ptr
        return sub_2217A0(GetHandleId(whichUnit))
    endfunction

    private function GetItemPtr takes item whichItem returns Ptr
        return sub_21FEA0(GetHandleId(whichItem))
    endfunction

    private function ConvertItemPtrToItem takes Ptr pItem returns item
        local integer v1 = sub_2135F0(pGameWar3)
        return GetItemByHandleId(sub_2B52E0(v1, pItem, 0))
    endfunction

    private function GetUnitFirstAbilityPtr takes unit whichUnit returns Ptr
        local Ptr pUnit = GetUnitPtr(whichUnit)
        local integer v1

        if (pUnit == 0) then
            return 0
        endif

        set v1 = pUnit + 0x1DC
        if (IntPtr[v1] == -1) then
            return 0
        endif

        return sub_8AE90(v1)
    endfunction

    private function GetNextAbilityPtr takes Ptr pAbility returns Ptr
        local integer v1
        if (pAbility == 0) then
            return 0
        endif

        set v1 = pAbility + 0x24
        if (IntPtr[v1] == -1) then
            return 0
        endif

        return sub_8AE90(v1)
    endfunction


    struct AbilityInventory extends array
        private static Ptr classFingerPrint

        public static method testInstance takes Ptr pAbility returns boolean
            return (pAbility != 0) and (PtrPtr[pAbility] == classFingerPrint)
        endmethod

        public static method get takes Ptr pAbility returns thistype
            if (not thistype.testInstance(pAbility)) then
                return 0
            endif
            return pAbility
        endmethod

        public static method getFirstOf takes unit whichUnit returns thistype
            local Ptr pAbility
            if (whichUnit == null) then
                return 0
            endif
            set pAbility = GetUnitFirstAbilityPtr(whichUnit)
            loop
                exitwhen (pAbility == 0) or thistype.testInstance(pAbility)
                set pAbility = GetNextAbilityPtr(pAbility)
            endloop
            return pAbility
        endmethod

        public method next takes nothing returns thistype
            local Ptr pAbility = this
            if (pAbility == 0) then
                return 0
            endif
            loop
                set pAbility = GetNextAbilityPtr(pAbility)
                exitwhen (pAbility == 0) or thistype.testInstance(pAbility)
            endloop
            return pAbility
        endmethod

        public method getSize takes nothing returns integer
            return sub_58CA70(this)
        endmethod

        public method getItemInSlot takes integer itemSlot returns item
            local Ptr pItem = sub_58D480(this, itemSlot)
            if (pItem == 0) then
                return null
            endif
            return ConvertItemPtrToItem(pItem)
        endmethod

        public method addItem takes item whichItem, boolean playSound returns boolean
            local Ptr pItem = GetItemPtr(whichItem)
            if (pItem == 0) then
                return false
            endif

            return sub_576090(this, pItem, playSound)
        endmethod

        public method addItemInSlot takes item whichItem, integer itemSlot, boolean playSound returns boolean
            local Ptr pItem = GetItemPtr(whichItem)
            if (pItem == 0) then
                return false
            endif

            return sub_576100(this, pItem, itemSlot, playSound)
        endmethod

        public method hasItem takes item whichItem returns boolean
            local Ptr pItem = GetItemPtr(whichItem)
            if (pItem == 0) then
                return false
            endif

            return sub_57CE20(this, pItem)
        endmethod

        public method removeItem takes item whichItem returns boolean
            local Ptr pItem = GetItemPtr(whichItem)
            if (pItem == 0) then
                return false
            endif

            return sub_59A900(this, pItem)
        endmethod

        public method swapSlot takes integer thisSlot, thistype other, integer otherSlot returns boolean
            local Ptr thisOwner = PtrPtr[this + 0x30]
            local Ptr otherOwner = PtrPtr[other + 0x30]
            local IntPtr src
            local IntPtr dst
            local integer temp0
            local integer temp1
            local integer temp2

            if (thisOwner != otherOwner) then
                return false
            endif
            if (thisSlot < 0) or (thisSlot >= this.getSize()) then
                return false
            endif
            if (otherSlot < 0) or (otherSlot >= other.getSize()) then
                return false
            endif

            set src = IntPtr(this + 0x70 + (thisSlot * 4 * 3))
            set dst = IntPtr(other + 0x70 + (otherSlot * 4 * 3))

            set temp0 = src[0]
            set temp1 = src[1]
            set temp2 = src[2]

            set src[0] = dst[0]
            set src[1] = dst[1]
            set src[2] = dst[2]
            set dst[0] = temp0
            set dst[1] = temp1
            set dst[2] = temp2

            call sub_6C7EF0(thisOwner)

            return true
        endmethod

        private static method onInit takes nothing returns nothing
            set thistype.classFingerPrint = JNGetModuleHandle("Game.dll") + 0xB18D88
        endmethod
    endstruct


    private function Init takes nothing returns nothing
        set pGameWar3 = PtrPtr[JNGetModuleHandle("Game.dll") + 0xD305E0]
    endfunction
endlibrary
