$(function()
{
	
	$("a[href^='http'], a[href^='//']").not('[rel~=external]').filter(function()
	{
		return this.host != window.location.host;
	}).attr('rel', function(index, attr)
	{
		return $.trim(attr+' external');
	});
	
	$("a[rel~=external]").click(function()
	{
		var track_path = null
		if (this.hostname != null && this.hostname != window.location.hostname)
		{
			track_path = '/external/' + this.hostname;
		}
		else
		{
			track_path = this.pathname + this.search;
			if (track_path.length && track_path[0] != '/')
			{
				track_path = '/' + track_path; // add the leading slash for IE
			}
		}
		if (track_path && typeof(pageTracker) != 'undefined' && pageTracker._trackPageview)
		{
			pageTracker._trackPageview(track_path)
		}
	});
	
});
