$(function()
{
	var controls = $('<p class="controls"><'+'/p>').prependTo($('body'));
	$('<span>Normal<'+'/span>').appendTo(controls).click(function(){
		$('header').toggleClass('large');
		$(this).text($('header').hasClass('large') ? 'Large' : 'Normal');
		return false;
	});
	$('<span href="#">White<'+'/span>').appendTo(controls).click(function(){
		$('body').toggleClass('reverse');
		$(this).text($('body').hasClass('reverse') ? 'Black' : 'White');
		return false;
	});
});
