function CreateDoublyLinkedList(elementsPerTick)
	local newdll = 
	{
		firstLink = nil,
		lastLink = nil,
		iterator = 
		{
			currentLink = nil,
			elementsPerTick = elementsPerTick
		},
		dataIdentifierToLink = {},
		
		--Methods
		AddLink = function(data, dataIdentifier) AddLink(newdll, data, dataIdentifier) end,
		RemoveLink = function(dataIdentifier) RemoveLink(newdll, dataIdentifier) end,
		RestartIterator = function() RestartIterator(newdll) end,
		NextLink = function() NextLink(newdll) end
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
		data = data,
		--When a link has been removed valid will be false
		valid = true
	}
	
	--If this is the first link then add it as the first link
	if linkedList.firstLink == nil then
		linkedList.firstLink = newLink
	end
	
	--If any previous link then add ref from that to the new link
	if linkedList.lastLink ~= nil then
		linkedList.lastLink.nextLink = newLink
	end
	linkedList.lastLink = newLink
	
	--Add ref from data to this link
	linkedList.dataIdentifierToLink[dataIdentifier] = newLink
end

function RemoveLink(linkedList, dataIdentifier)
	local link = linkedList.dataIdentifierToLink[dataIdentifier]
	
	--Need to link the previous and next link together so theycircumvent tis removed link
end

function RestartIterator(linkedList)
	
end

function NextLink(linkedList)
	return linkedList
end