// HTML5 placeholder plugin version 1.01
// Copyright (c) 2010-The End of Time, Mike Taylor, http://miketaylr.com
// MIT Licensed: http://www.opensource.org/licenses/mit-license.php
//
// Enables cross-browser HTML5 placeholder for inputs, by first testing
// for a native implementation before building one.
//
//
// USAGE:
//$('input[placeholder]').placeholder();

// <input type="text" placeholder="username">
(function($){
  //feature detection
  var hasPlaceholder = 'placeholder' in document.createElement('input');

  //sniffy sniff sniff -- just to give extra left padding for the older
  //graphics for type=email and type=url
  var isOldOpera = $.browser.opera && $.browser.version < 10.5;

  $.fn.placeholder = function(options) {
    //merge in passed in options, if any
    var options = $.extend({}, $.fn.placeholder.defaults, options),
    //cache the original 'left' value, for use by Opera later
    o_left = options.placeholderCSS.left;

    //first test for native placeholder support before continuing
    //feature detection inspired by ye olde jquery 1.4 hawtness, with paul irish
    return (hasPlaceholder) ? this : this.each(function() {
      //TODO: if this element already has a placeholder, exit
      var $this = $(this);
      if(!$this.attr('placeholderdone')) {
        //local vars
        var inputVal = $.trim($this.val()),
            inputWidth = '150px',
            inputHeight = '18px',

            //grab the inputs id for the <label @for>, or make a new one from the Date
            inputId = (this.id) ? this.id : 'placeholder' + (new Date().getTime()),
            placeholderText = $this.attr('placeholder'),
            placeholder = $('<label id="label-'+inputId+'" for='+ inputId +' class="placeholder">'+ placeholderText + '</label>');

            //stuff in some calculated values into the placeholderCSS object
            options.placeholderCSS['width'] = inputWidth;
            options.placeholderCSS['height'] = inputHeight;

            // adjust position of placeholder
            placeholder.css(options.placeholderCSS);

        //place the placeholder
        $this.wrap(options.inputWrapper);
        $this.attr('id', inputId).after(placeholder);
        $this.attr('placeholderdone', true);

        //if the input isn't empty
        if (inputVal && inputVal != ''){
          placeholder.hide();
        };

        //hide placeholder on focus
        $this.focus(function(){
          if (!$.trim($this.val())){
            placeholder.hide();
          };
        });

        //show placeholder if the input is empty
        $this.blur(function(){
          if (!$.trim($this.val())){
            placeholder.show();
          };
        });

      }
    });
  };

  //expose defaults
  $.fn.placeholder.defaults = {
    //you can pass in a custom wrapper
    inputWrapper: '<span style="position:relative"></span>',

    //more or less just emulating what webkit does here
    //tweak to your hearts content
    placeholderCSS: {
      'position': 'absolute',
      'left': '1px',
      'top': '-3px',
      'overflow-x': 'hidden'
    }
  };
})(jQuery);



$(document).ready(function() {

//cowntdown function. Set the date by modifying the date in next line (January 01, 2013 00:00:00):
		// var austDay = new Date("May 1, 2012 00:00:00");
		// 	$('#countdown').countdown({until: austDay, layout: '<div class="item"><p>{dn}</p> <span class="days">{dl}</span><div class="lines"></div></div> <div class="item"><p>{hn}</p> <span class="hours">{hl}</span><div class="lines"></div></div> <div class="item"><p>{mn}</p> <span class="minutes">{ml}</span><div class="lines"></div></div> <div class="item"><p>{sn}</p> <span class="seconds">{sl}</span></div>'});
		// 	$('#year').text(austDay.getFullYear());

//function for the social hover effect - tooltips
	// $('.tooltip').tipsy
	// ({
	// 	fade: true,
	// 	gravity: 's'
	// });


//function for the twitter feed

	// $('#twitter').tweets({username: 'deliciousthemes', count: 5, cycle: true, showTimestamps: false});

//Tabs

	//When page loads...
	$('.tabs-wrapper').each(function() {
		$(this).find(".tab-content").hide(); //Hide all content
		$(this).find("ul.tabs li:first").addClass("active").show(); //Activate first tab
		$(this).find(".tab-content:first").show(); //Show first tab content
	});

	//On Click Event
	$("ul.tabs li").click(function(e) {
		$(this).parents('.tabs-wrapper').find("ul.tabs li").removeClass("active"); //Remove any "active" class
		$(this).addClass("active"); //Add "active" class to selected tab
		$(this).parents('.tabs-wrapper').find(".tab-content").hide(); //Hide all tab content

		var activeTab = $(this).find("a").attr("href"); //Find the href attribute value to identify the active tab + content
		$("li.tab-item:first-child").css("background", "none" );
		$(this).parents('.tabs-wrapper').find(activeTab).show(); //Fade in the active ID content

		e.preventDefault();
	});

	$("ul.tabs li a").click(function(e) {
		e.preventDefault();
	})

	$("li.tab-item:last-child").addClass('last-item');
	$("ul#related li:last-child").addClass('last');


//Progress Bar

	// var $progress_bar = jQuery('#bar'),
	// $progress_piece = jQuery('#piece'),
	// bar_multiply = 5.8,
	// bar_percent = 70,
	// bar_percent_width = bar_multiply*bar_percent;
	// $("#percent-tooltip").css("left", bar_percent_width - 22 );
	// if ( bar_percent === 100 ) bar_percent_width = 580;

	// $progress_bar.animate({ width: ( bar_percent_width -8 ) }, 2000, function(){
	// 	jQuery(this).animate({ width: ( bar_percent_width ) }, 200);
	// 	jQuery('#percent-tooltip').animate({'opacity': 'toggle'}, 300);
	// 	if ( bar_percent != 100 )
	// 		$progress_piece.css({left: (bar_percent_width), 'display': 'block'});
	// });

	// binds form submission and fields to the validation engine
	jQuery("#loginform,#subscribeform,#passwordform").validationEngine();

  $('input[placeholder]:not([placeholderdone])').placeholder();

});