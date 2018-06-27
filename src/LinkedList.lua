function CreateDoublyLinkedList()
	local newdll =
	{
		firstLink = nil,
		lastLink = nil,
		iterator =
		{
			currentLink = nil,
			linksPerTick = nil
		},
		dataIdentifierToLink = {},
		count = 0,
		freeIndexes = {}
	}

	return newdll
end

function AddLink(linkedList, data, dataIdentifier)
	--Create new link
	local newLink =
	{
		--Add ref to the previous link
		prevLink = linkedList.lastLink,
		nextLink = nil,
		data = data
	}
	-- we save the position we insert at, because the array backing the linked list is sparse
	-- this means that
	local insert_at
	if #linkedList.freeIndexes > 0 then
		insert_at = table.remove(linkedList.freeIndexes)
		linkedList[insert_at] = newLink
	else
		insert_at = #linkedList + 1
		table.insert(linkedList, insert_at, newLink)
	end


	--If there is no first link then this is the first link
	--so add it as the first link
	if linkedList.firstLink == nil then
		linkedList.firstLink = insert_at
	end

	--If there is any previous link then add ref from that to the new link
	--to continue the chain
	if linkedList.lastLink ~= nil then
		linkedList[linkedList.lastLink].nextLink = insert_at
	end
	--New links are always added to the end of the chain so this link
	--must now be the last link
	linkedList.lastLink = insert_at

	--Add an easy way to get hold of the link instead of traversing
	--the whole chain
	linkedList.dataIdentifierToLink[dataIdentifier] = insert_at

	linkedList.count = linkedList.count + 1
end

function RemoveLink(linkedList, dataIdentifier)
	local index = linkedList.dataIdentifierToLink[dataIdentifier]
	local link = linkedList[index]
	--The game can send multiple destroy events for a single entity
	--sp this method has to support that
	if link ~= nil then
		table.insert(linkedList.freeIndexes, index)
		linkedList[index] = nil
		linkedList.dataIdentifierToLink[dataIdentifier] = nil

		--Need to link the previous and next link together so they
		--circumvent this removed link so the chain isn't broken
		if link.prevLink ~= nil then
			linkedList[link.prevLink].nextLink = link.nextLink
		end
		if link.nextLink ~= nil then
			linkedList[link.nextLink].prevLink = link.prevLink
		end

		--Need update the first link and last link because
		--this link might be one or both of those.
		if linkedList.firstLink == index then
			linkedList.firstLink = link.nextLink
		end
		if linkedList.lastLink == index then
			linkedList.lastLink = link.prevLink
		end

		--The iterators current link might be this link so to remove it
		--the iterator should move to the next link
		if linkedList.iterator.currentLink == index then
			linkedList.iterator.currentLink = linkedList[link.nextLink]
		end

		linkedList.count = linkedList.count - 1
	end
end

function RestartIterator(linkedList, ticksToIterateChain)
	linkedList.iterator.currentLink = linkedList.firstLink
	if linkedList.count == 0 then
		linkedList.iterator.linksPerTick = 0
	else
		linkedList.iterator.linksPerTick = math.ceil(linkedList.count / ticksToIterateChain)
	end
end

function NextLink(linkedList)
	if linkedList.iterator.currentLink == nil then
		return nil
	end

	local toReturn = linkedList[linkedList.iterator.currentLink]
	linkedList.iterator.currentLink = toReturn.nextLink
	return toReturn
end

--[[
local list = CreateDoublyLinkedList()
AddLink(list, 1, 1)
AddLink(list, 2, 2)
AddLink(list, 3, 3)
AddLink(list, 4, 4)
AddLink(list, 5, 5)
AddLink(list, 6, 6)
AddLink(list, 7, 7)
AddLink(list, 8, 8)

RestartIterator(list, 1)
local link = NextLink(list)
while link ~= nil do
    print(link.data)
    link = NextLink(list)
end

for k, v in ipairs(list) do
    print(k .. '=' .. v.data)
end

RemoveLink(list, 4)
RemoveLink(list, 5)

RestartIterator(list, 1)
local link = NextLink(list)
while link ~= nil do
    print(link.data)
    link = NextLink(list)
end

for k, v in ipairs(list) do
    print(k .. '=' .. v.data)
end

AddLink(list, 9, 9)
AddLink(list, 10, 10)

RestartIterator(list, 1)
local link = NextLink(list)
while link ~= nil do
    print(link.data)
    link = NextLink(list)
end

for k, v in ipairs(list) do
    print(k .. '=' .. v.data)
end
--]]