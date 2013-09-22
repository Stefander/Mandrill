//
//  RFSprite.m
//  spriteTest
//
//  Created by Johannis on 12/30/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Sprite.h"
#import "RFGame.h"
#import "ResourceManager.h"

@interface Sprite ()
-(void)calculateVerts;
-(void)calculateTexQuad;
-(void)initImpl;
-(void)displaySubSprite:(CGPoint)point;
@end

@implementation Sprite

@synthesize position;
@synthesize alpha;
@synthesize currentIndex;
@synthesize spritePortion;
@synthesize depthTestPoint;
@synthesize renderLayer;
@synthesize texIndex;
@synthesize spriteSize;
@synthesize sizeX;
@synthesize imageSizeX;
@synthesize imageSizeY;
@synthesize vertices;
@synthesize texName;
@synthesize texes;
@synthesize sizeY;
@synthesize spriteBounds;
@synthesize scaleX;
@synthesize scaleY;
@synthesize scale;

-(id)initWithSprite:(Sprite *)sprite
{
	texName = [[NSString alloc] initWithString:[sprite texName]];
	
	imageSizeX = [[ResourceManager sharedResourceManager] getSize:texName];
	imageSizeY = [[ResourceManager sharedResourceManager] getSize:texName];
	spritePortion = CGRectMake(0,0,imageSizeX,imageSizeY);
	alpha = 1.0f;
	//depthTestPoint = CGPointMake(imageSizeX/2,imageSizeY);
	scale = 1.0f;
	[self initImpl];
	return self;
}

-(id)initWithSprite:(Sprite *)sprite texPortion:(CGRect)portion
{
	texName = [[NSString alloc] initWithString:[sprite texName]];
	//texIndex = sprite.texIndex;
	spritePortion = portion;
	imageSizeX = [[ResourceManager sharedResourceManager] getSize:texName];
	imageSizeY = [[ResourceManager sharedResourceManager] getSize:texName];
	alpha = 1.0f;
	scale = 1.0f;
	[self initImpl];
	return self;
}

-(id)initWithSprite:(Sprite*)sprite renderLayer:(int)layer texPortion:(CGRect)portion scale:(float)spriteScale;
{
	texName = [[NSString alloc] initWithString:[sprite texName]];
	imageSizeX = [[ResourceManager sharedResourceManager] getSize:texName];
	imageSizeY = [[ResourceManager sharedResourceManager] getSize:texName];
	scale = spriteScale;
	
	spritePortion = portion;
	[self initImpl];
	return self;
}

-(id)initWithTexture:(Texture2D*)image
{
	texName = [[NSString alloc] initWithString:[image texName]];
	renderLayer = 0;
	spritePortion = CGRectMake(0,0,[[ResourceManager sharedResourceManager] getSize:texName],[[ResourceManager sharedResourceManager] getSize:texName]);
	scale = 1.0f;
	
	imageSizeX = [[ResourceManager sharedResourceManager] getSize:texName];
	imageSizeY = [[ResourceManager sharedResourceManager] getSize:texName];

	[self initImpl];
	return self;
}

-(void)nextFrame
{
	currentIndex++;
	[self setSpriteIndex:currentIndex spriteSize:spritePortion.size.width];
}

-(void)setSpriteIndex:(int)index spriteSize:(int)size
{
	int targetRow=0;
	int imagesOnRow = floor(imageSizeX/size);
	currentIndex = index;
	
	while((index*size)+size > targetRow*imageSizeX+imageSizeX)
	{
		targetRow++;
	}
	
	// Calculate the column
	int targetColumn = index-targetRow*imagesOnRow;

	self.spritePortion = CGRectMake(size*targetColumn,size*targetRow,size,size);
}

-(CGRect)calcPortion:(int)index
{
	int targetRow=0;
	currentIndex = index;
	CGFloat spriteWidth = spritePortion.size.width;
	int imagesOnRow = imageSizeX/spriteWidth;
	while((index*spriteWidth)+spriteWidth > targetRow*imageSizeX+imageSizeX)
	{
		targetRow++;
	}
	
	// Calculate the column
	int targetColumn = index-targetRow*imagesOnRow;
	return CGRectMake(spriteWidth*targetColumn,spriteWidth*targetRow,spriteWidth,spriteWidth);
}

-(id)initWithTexture:(Texture2D*)image texPortion:(CGRect)portion
{
	texName = [[NSString alloc] initWithString:[image texName]];
	renderLayer = 0;
	scale = 1.0f;
	spritePortion = portion;
	
	imageSizeX = [image contentSize].width;
	imageSizeY = [image contentSize].height;
	
	[self initImpl];
	return self;
}

-(void)setAlpha:(float)value
{
	if(value >= 0.0f)
	{
		alpha = value;
	}
	else if(value > 1.0f)
	{
		alpha = 1.0f;
	}
	else 
	{
		alpha = 0.0f;
	}

}

-(id)initWithTexture:(Texture2D*)image renderLayer:(int)layer texPortion:(CGRect)portion scale:(float)spriteScale
{
	texName = [[NSString alloc] initWithString:[image texName]];
	renderLayer = layer;
	scale = spriteScale;
	spritePortion = portion;
	
	imageSizeX = [image contentSize].width;
	imageSizeY = [image contentSize].height;
	
	[self initImpl];
	return self;
}

-(void) initImpl
{
	sizeX = spritePortion.size.width*scale;
	sizeY = spritePortion.size.height*scale;
	position = CGPointMake(0,0);
	spriteSize = CGSizeMake(SPRITESIZE, SPRITESIZE);
	alpha = 1.0f;
	currentIndex = -1;
	
	// Init vertex arrays
	texes = malloc( sizeof(texes[0]));
	vertices = malloc( sizeof(vertices[0]));
	
	[self calculateTexQuad];
	[self calculateVerts];
	[super init];
}

- (void)calculateTexCoordsAtOffset:(CGPoint)offsetPoint subImageWidth:(GLuint)subImageWidth subImageHeight:(GLuint)subImageHeight 
{
	CGFloat texWidthRatio = 1/imageSizeX;
	CGFloat texHeightRatio = 1/imageSizeY;
	
	texes[0].br_x = texWidthRatio * subImageWidth + (texWidthRatio * offsetPoint.x);
	texes[0].br_y = texHeightRatio * offsetPoint.y;
	
	texes[0].tr_x = texWidthRatio * subImageWidth + (texWidthRatio * offsetPoint.x);
	texes[0].tr_y = texHeightRatio * subImageHeight + (texHeightRatio * offsetPoint.y);
	
	texes[0].bl_x = texWidthRatio * offsetPoint.x;
	texes[0].bl_y = texHeightRatio * offsetPoint.y;
	
	texes[0].tl_x = texWidthRatio * offsetPoint.x;
	texes[0].tl_y = texHeightRatio * subImageHeight + (texHeightRatio * offsetPoint.y);
}


- (void)calculateVerticesAtPoint:(CGPoint)point subImageWidth:(GLuint)subImageWidth subImageHeight:(GLuint)subImageHeight centerOfImage:(BOOL)center {
	
	// Calculate the width and the height of the quad using the current image scale and the width and height
	// of the image we are going to render
	GLfloat quadWidth = subImageWidth * scale;
	GLfloat quadHeight = subImageHeight * scale;

	if(center) 
	{
		vertices[0].br_x = point.x + quadWidth / 2;
		vertices[0].br_y = point.y + quadHeight / 2;
		
		vertices[0].tr_x = point.x + quadWidth / 2;
		vertices[0].tr_y = point.y + -quadHeight / 2;
		
		vertices[0].bl_x = point.x + -quadWidth / 2;
		vertices[0].bl_y = point.y + quadHeight / 2;
		
		vertices[0].tl_x = point.x + -quadWidth / 2;
		vertices[0].tl_y = point.y + -quadHeight / 2;
	} 
	else 
	{
		vertices[0].br_x = point.x + quadWidth;
		vertices[0].br_y = point.y + quadHeight;
		
		vertices[0].tr_x = point.x + quadWidth;
		vertices[0].tr_y = point.y;
		
		vertices[0].bl_x = point.x;
		vertices[0].bl_y = point.y + quadHeight;
		
		vertices[0].tl_x = point.x;
		vertices[0].tl_y = point.y;
	}	
	
	depthTestPoint = CGPointMake(point.x+quadWidth/2,point.y+quadHeight);
}

-(void)calculateVerts
{
	vertices[0].bl_x = position.x;
	vertices[0].bl_y = SCREEN_HEIGHT-position.y;
	
	vertices[0].br_x = position.x+sizeX;
	vertices[0].br_y = SCREEN_HEIGHT-position.y;

	vertices[0].tr_x = position.x+sizeX;
	vertices[0].tr_y = SCREEN_HEIGHT-(position.y+sizeY);
	
	vertices[0].tl_x = position.x;
	vertices[0].tl_y = SCREEN_HEIGHT-(position.y+sizeY);
	
	// Create new sprite bounds
	spriteBounds = CGRectMake(position.x,position.y,sizeX,sizeY);
	
	depthTestPoint = CGPointMake(position.x+sizeX/2,position.y+sizeY);
}

-(void)calculateTexQuad
{
	CGFloat texWidthRatio = (1/imageSizeX);
	CGFloat texHeightRatio = (1/imageSizeY);
	
	texes[0].tr_x = ((spritePortion.origin.x+spritePortion.size.width)/imageSizeX)-texWidthRatio;
	texes[0].tr_y = ((spritePortion.origin.y+spritePortion.size.height)/imageSizeY)-texHeightRatio;
	
	texes[0].br_x = ((spritePortion.origin.x+spritePortion.size.width)/imageSizeX)-texWidthRatio;
	texes[0].br_y = (spritePortion.origin.y/imageSizeY)+texHeightRatio;
	
	texes[0].tl_x = (spritePortion.origin.x/imageSizeX)+texWidthRatio;
	texes[0].tl_y = ((spritePortion.origin.y+spritePortion.size.height)/imageSizeY)-texHeightRatio;
	
	texes[0].bl_x = (spritePortion.origin.x/imageSizeX)+texWidthRatio;
	texes[0].bl_y = (spritePortion.origin.y/imageSizeY)+texHeightRatio;
}

-(void)updateTexture:(NSString *)texN
{
    [texName release];
    texName = [[NSString alloc] initWithString:texN];
	renderLayer = 0;
}

-(void)setSpriteSize:(CGSize)size
{
	spritePortion = CGRectMake(spritePortion.origin.x, spritePortion.origin.y, size.width, size.height);
	sizeX = spritePortion.size.width;
	sizeY = spritePortion.size.height;
	[self calculateTexQuad];
}

-(void)displaySubSprite:(CGPoint)point
{
	spritePortion = CGRectMake(point.x,point.y,spriteSize.width,spriteSize.height);
}

-(Texture2D *)getTexture
{
	return [[ResourceManager sharedResourceManager] getTextureWithName:texName];
}

-(void)render
{
	// Only render when visible
	if(alpha > 0)
		[[Renderer instance] addToQueue:self];
}

-(void)setSpritePortion:(CGRect)portion
{
	if(portion.size.width != sizeX || portion.size.height != sizeY || portion.origin.x != spritePortion.origin.x || portion.origin.y != spritePortion.origin.y)
	{
		spritePortion = portion;
		sizeX = portion.size.width;
		sizeY = portion.size.height;
		
		[self calculateTexQuad];
		[self calculateVerts];
	}
}

-(void)setPortion:(int)index
{
	if(index != currentIndex)
		self.spritePortion = [self calcPortion:index];
}

// For game depth testing
- (NSComparisonResult)compare:(id)otherObject 
{
	if(depthTestPoint.y < [otherObject depthTestPoint].y)
	{
		return NSOrderedAscending;
	}
	else 
	{
		return NSOrderedDescending;
	}
}

-(void)setScaleX:(float)xScale
{
	sizeX = spritePortion.size.width*xScale;
	scaleX = xScale;
	[self calculateVerts];
}

-(void)setScaleY:(float)yScale
{
	sizeY = spritePortion.size.height*yScale;
	scaleY = yScale;
	[self calculateVerts];
}

-(void)setScale:(CGFloat)spriteScale
{
	sizeX = spritePortion.size.width*spriteScale;
	sizeY = spritePortion.size.height*spriteScale;
	scaleX = spriteScale;
	scaleY = spriteScale;
	
	scale = spriteScale;
	[self calculateVerts];
}

-(void)setPosition:(CGPoint)point
{
	position = point;
	[self calculateVerts];
}

-(void)dealloc
{
	free(texes);
	free(vertices);
	[texName release];
	[super dealloc];
}

@end
