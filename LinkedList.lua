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
		count = 0
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
	
	--If there is no first link then this is the first link
	--so add it as the first link
	if linkedList.firstLink == nil then
		linkedList.firstLink = newLink
	end
	
	--If there is any previous link then add ref from that to the new link
	--to continue the chain
	if linkedList.lastLink ~= nil then
		linkedList.lastLink.nextLink = newLink
	end
	--New links are always added to the end of the chain so this link 
	--must now be the last link
	linkedList.lastLink = newLink
	
	--Add an easy way to get hold of the link instead of traversing
	--the whole chain
	linkedList.dataIdentifierToLink[dataIdentifier] = newLink
	
	linkedList.count = linkedList.count + 1
end

function RemoveLink(linkedList, dataIdentifier)
	local link = linkedList.dataIdentifierToLink[dataIdentifier]
	--The game can send multiple destroy events for a single entity
	--sp this method has to support that
	if link ~= nil then
		linkedList.dataIdentifierToLink[dataIdentifier] = nil
		
		--Need to link the previous and next link together so they 
		--circumvent this removed link so the chain isn't broken
		if link.prevLink ~= nil then
			link.prevLink.nextLink = link.nextLink
		end
		if link.nextLink ~= nil then
			link.nextLink.prevLink = link.prevLink
		end
		
		--Need update the first link and last link because
		--this link might be one or both of those.
		if linkedList.firstLink == link then
			linkedList.firstLink = link.nextLink
		end
		if linkedList.lastLink == link then
			linkedList.lastLink = link.prevLink
		end
		
		--The iterators current link might be this link so to remove it
		--the iterator should move to the next link
		if linkedList.iterator.currentLink == link then
			linkedList.iterator.currentLink = link.nextLink
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
	
	local toReturn = linkedList.iterator.currentLink
	linkedList.iterator.currentLink = linkedList.iterator.currentLink.nextLink
	return toReturn
end