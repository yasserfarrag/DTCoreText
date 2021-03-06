//
//  DTAttributedTextView.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 1/12/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "DTAttributedTextView.h"
#import "DTCoreText.h"
#import <QuartzCore/QuartzCore.h>

@interface DTAttributedTextView ()

- (void)setup;

@end



@implementation DTAttributedTextView
{
	DTAttributedTextContentView *_attributedTextContentView;
	UIView *_backgroundView;

	// these are pass-through, i.e. store until the content view is created
	__unsafe_unretained id textDelegate;
	NSAttributedString *_attributedString;
	BOOL _shouldDrawLinks;
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	
	if (self)
	{
		[self setup];
	}
	
	return self;
}

- (void)dealloc 
{
	_attributedTextContentView.delegate = nil;
	[_attributedTextContentView removeObserver:self forKeyPath:@"frame"];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	[self attributedTextContentView];
	
	// layout custom subviews for visible area
	[_attributedTextContentView layoutSubviewsInRect:self.bounds];
}

- (void)awakeFromNib
{
	[self setup];
}

// default
- (void)setup
{
	if (!self.backgroundColor)
	{
		self.backgroundColor = [DTColor whiteColor];
		self.opaque = YES;
		return;
	}
	
	CGFloat alpha = [self.backgroundColor alphaComponent];
	
	if (alpha < 1.0)
	{
		self.opaque = NO;
	}
	else 
	{
		self.opaque = YES;
	}
	
	self.autoresizesSubviews = NO;
	self.clipsToBounds = YES;
}

// override class e.g. for mutable content view
- (Class)classForContentView
{
	return [DTAttributedTextContentView class];
}

#pragma mark External Methods
- (void)scrollToAnchorNamed:(NSString *)anchorName animated:(BOOL)animated
{
	NSRange range = [self.attributedTextContentView.attributedString rangeOfAnchorNamed:anchorName];
	
	if (range.length != NSNotFound)
	{
		// get the line of the first index of the anchor range
		DTCoreTextLayoutLine *line = [self.attributedTextContentView.layoutFrame lineContainingIndex:range.location];
		
		// make sure we don't scroll too far
		CGFloat maxScrollPos = self.contentSize.height - self.bounds.size.height + self.contentInset.bottom + self.contentInset.top;
		CGFloat scrollPos = MIN(line.frame.origin.y, maxScrollPos);
		
		// scroll
		[self setContentOffset:CGPointMake(0, scrollPos) animated:animated];
	}
}

#pragma mark Notifications
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == _attributedTextContentView && [keyPath isEqualToString:@"frame"])
	{
		CGRect newFrame = [[change objectForKey:NSKeyValueChangeNewKey] CGRectValue];
		self.contentSize = newFrame.size;
	}
}

#pragma mark Properties
- (DTAttributedTextContentView *)attributedTextContentView
{
	if (!_attributedTextContentView)
	{
		// subclasses can specify a DTAttributedTextContentView subclass instead
		Class classToUse = [self classForContentView];
		
		CGRect frame = UIEdgeInsetsInsetRect(self.bounds, self.contentInset);
		_attributedTextContentView = [[classToUse alloc] initWithFrame:frame];
		
		_attributedTextContentView.userInteractionEnabled = YES;
		_attributedTextContentView.backgroundColor = self.backgroundColor;
		_attributedTextContentView.shouldLayoutCustomSubviews = NO; // we call layout when scrolling
		
		// adjust opaqueness based on background color alpha
		CGFloat alpha = [self.backgroundColor alphaComponent];
		
		if (alpha < 1.0)
		{
			_attributedTextContentView.opaque = NO;
		}
		else
		{
			_attributedTextContentView.opaque = YES;
		}

		// set text delegate if it was set before instantiation of content view
		_attributedTextContentView.delegate = textDelegate;
		
		// pass on setting
		_attributedTextContentView.shouldDrawLinks = _shouldDrawLinks;
		
		// set text we previously got
		_attributedTextContentView.attributedString = _attributedString;
		
		// only get contentSize if we have an attributed string
		if (_attributedString)
		{
			CGSize neededSize = [_attributedTextContentView sizeThatFits:CGSizeZero];
			frame.size = neededSize;
			_attributedTextContentView.frame = frame;
			
			self.contentSize = neededSize;
		}
		
		// we want to know if the frame changes so that we can adjust the scrollview content size
		[_attributedTextContentView addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
		
		[self addSubview:_attributedTextContentView];
	}		
	
	return _attributedTextContentView;
}

- (void)setBackgroundColor:(DTColor *)newColor
{
	if ([newColor alphaComponent]<1.0)
	{
		super.backgroundColor = newColor;
		_attributedTextContentView.backgroundColor = [DTColor clearColor];
		self.opaque = NO;
	}
	else 
	{
		super.backgroundColor = newColor;
		
		if (_attributedTextContentView.opaque)
		{
			_attributedTextContentView.backgroundColor = newColor;
		}
	}
}

- (UIView *)backgroundView
{
	if (!_backgroundView)
	{
		_backgroundView = [[UIView alloc] initWithFrame:self.bounds];
		_backgroundView.backgroundColor	= [DTColor whiteColor];
		
		// default is no interaction because background should have no interaction
		_backgroundView.userInteractionEnabled = NO;

		[self insertSubview:_backgroundView belowSubview:self.attributedTextContentView];
		
		// make content transparent so that we see the background
		_attributedTextContentView.backgroundColor = [DTColor clearColor];
		_attributedTextContentView.opaque = NO;
	}		
	
	return _backgroundView;
}

- (void)setBackgroundView:(UIView *)backgroundView
{
	if (_backgroundView != backgroundView)
	{
		[_backgroundView removeFromSuperview];
		_backgroundView = backgroundView;
		
		if (_attributedTextContentView)
		{
			[self insertSubview:_backgroundView belowSubview:_attributedTextContentView];
		}
		else
		{
			[self addSubview:_backgroundView];
		}
		
		if (_backgroundView)
		{
			// make content transparent so that we see the background
			_attributedTextContentView.backgroundColor = [DTColor clearColor];
			_attributedTextContentView.opaque = NO;
		}
		else 
		{
			_attributedTextContentView.backgroundColor = [DTColor whiteColor];
			_attributedTextContentView.opaque = YES;
		}
	}
}

- (void)setAttributedString:(NSAttributedString *)string
{
	_attributedString = string;

	// might need layout for visible custom views
	[self setNeedsLayout];

	if (_attributedTextContentView)
	{
		// pass it along if contentView already exists
		_attributedTextContentView.attributedString = string;
	
		// adjust content size right away
		self.contentSize = _attributedTextContentView.frame.size;
	}
}

- (NSAttributedString *)attributedString
{
	return _attributedString;
}

- (void)setFrame:(CGRect)frame
{
	if (!CGRectEqualToRect(self.frame, frame))
	{
		if (self.frame.size.width != frame.size.width)
		{
			// height does not matter, that will be determined anyhow
			CGRect contentFrame = CGRectMake(0, 0, frame.size.width - self.contentInset.left - self.contentInset.right, 0);
			
			_attributedTextContentView.frame = contentFrame;
		}
		[super setFrame:frame];
	}
}

- (void)setTextDelegate:(id<DTAttributedTextContentViewDelegate>)aTextDelegate
{
	// store unsafe pointer to delegate because we might not have a contentView yet
	textDelegate = aTextDelegate;
	
	// set it if possible, otherwise it will be set in contentView lazy property
	_attributedTextContentView.delegate = aTextDelegate;
}

- (id<DTAttributedTextContentViewDelegate>)textDelegate
{
	return _attributedTextContentView.delegate;
}

- (void)setShouldDrawLinks:(BOOL)shouldDrawLinks
{
	_shouldDrawLinks = shouldDrawLinks;
	_attributedTextContentView.shouldDrawLinks = YES;
}

@synthesize attributedTextContentView = _attributedTextContentView;
@synthesize attributedString = _attributedString;
@synthesize textDelegate = _textDelegate;

@synthesize shouldDrawLinks = _shouldDrawLinks;

@end
