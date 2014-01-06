// add anchors to each section header
(function()
{
	
	// old browsers suck. not using jQuery here to keep things snappy
	if (!document.addEventListener || !document.querySelectorAll) return;
	
	document.addEventListener("DOMContentLoaded", function()
	{
		var headers = document.querySelectorAll('h1[id],h2[id],h3[id]');
		for (var idxHeader = 0; idxHeader < headers.length; ++idxHeader)
		{
			var header = headers[idxHeader];
			var anchor = document.createElement('a');
			anchor.href = '#'+header.id;
			anchor.className = 'section_anchor';
			header.appendChild(anchor);
		}
	}, false);
	
})();
