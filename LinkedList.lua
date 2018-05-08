function CreateDoublyLinkedList(elementsPerTick)
	local newdll = 
	{
		firstElement,
		lastElement,
		iterator = 
		{
			currentElement,
			elementsPerTick = elementsPerTick
		},
		entityToElement
	}
	
	return newdll
end

function AddLink(linkedList, entity)
	local newLink = 
	{
		prevLink = linkedList.lastElement,
		nextLink,
		entity = entity
	}
	
	if lastElement ~= nil then
		lastElement.nextLink = newLink
	end
end

function RemoveLink(linkedList, link)

end

function RestartIterator(linkedList)
	
end

function NextLink(linkedList)
	return linkedList
end