package physics
{
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.ui.ContextMenuBuiltInItems;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import physics.PhysObjectType;
	import physics.PhysWorld;
	import physics.PhysObject;
	import math.CustomMath;
	import physics.CollisionData;

	public class PhysConvexObject
	{
		// PUBLIC
		public var bodyName:String;
		public var contactList:Array = new Array();
		// PRIVATE
		private var mMass:Number = 0;
		private var mCenterOfMass:Point = new Point(0,0);
		private var mCollisionPoints:Array;
		private var mLinearVelocity:Point = new Point(0, 0);
		private var mCurrentVelocity:Point = new Point(0, 0);
		private var mScale:Number = 1;
		private var mAcceleration:Number = 0.5;
		private var mAngularVelocity:Number = 0;
		private var mBounds:Rectangle;
		private var mConvexHeight:Number;
		private var mConvexWidth:Number;
		private var mRotation:Number = 0;
		private var mXPos:Number = 0;
		private var mYPos:Number = 0;
		private var mDebugSprite:Sprite;					// Om de data op het scherm te tekenen
		private var mPersistCollCheck:Boolean = false;		// Of de engine elke frame moet blijven collisionchecken
		private var mCollLineLength:Number = 20;			// De lengte van de lijn voor de collision
		private var topBorder:Number = 40;
		private var bottomBorder:Number = 330;
		private var mPhysWorld:PhysWorld;
		
		/// Constructor voor het convex physics object
		public function PhysConvexObject(world:PhysWorld,inName:String,points:Array,mass:Number,x:Number,y:Number):void
		{
			mPhysWorld = world;
			
			mCollisionPoints = new Array();
			for (var i:Number = 0; i < points.length; i++)
			{
				mCollisionPoints.push(points[i]);
			}
			
			mDebugSprite = world.mDebugSprite;
			mConvexHeight = getConvexHeight(points);
			var tempBounds:Rectangle = CustomMath.calculateBounds(mCollisionPoints);
			mBounds = new Rectangle(tempBounds.left + mXPos, tempBounds.top + mYPos, tempBounds.width, tempBounds.height);
			normalizeCollPoints(mCollisionPoints);
			
			if (mConvexHeight > 80)
			{	
				mScale = 80 / mConvexHeight;
				scaleConvex(mScale);
				mConvexHeight = getConvexHeight(points);
			}
			mConvexWidth = getConvexWidth(points);
			mMass = mass;
			mXPos = x;
			mYPos = y;
			
			mCenterOfMass = CustomMath.berekenZwaartepunt(points);
			bodyName = inName;
			
			//mAngularVelocity = (bodyName != "auto") ? (Math.random() * 5) - 2.5 : 0;
			mAcceleration = (bodyName != "player") ? 0.05 : 0.3;
		}
		
		private function scaleConvex(scaleValue:Number):void
		{
			for (var i:Number = 0; i < mCollisionPoints.length; i++)
			{
				mCollisionPoints[i] = CustomMath.scalePuntOmOrigin(mCollisionPoints[i], new Point(0,0), scaleValue);
			}
		}
		
		private function normalizeCollPoints(collPoints:Array):void
		{
			var centerX:Number = mBounds.left + mBounds.width / 2;
			var centerY:Number = mBounds.top + mBounds.height / 2;
			
			for (var i:Number = 0; i < collPoints.length; i++)
			{
				collPoints[i].x -= centerX;
				collPoints[i].y -= centerY;
			}
		}
		
		// Gets
		public function getAngle():Number									{ return mRotation;			}
		public function getLinearVelocity():Point 							{ return mLinearVelocity; 	}
		public function getCurrentVelocity():Point 							{ return mCurrentVelocity; 	}
		public function getAngularVelocity():Number 						{ return mAngularVelocity; 	}
		public function getCenterOfMass():Point 							{ return mCenterOfMass; 	}
		public function getMass():Number									{ return mMass;				}
		public function getHeight():Number									{ return mConvexHeight; 	}
		public function getWidth():Number									{ return mConvexWidth;		}
		public function getBoundingBox():Rectangle							{ return mBounds;			}
		public function getPosition():Point									{ return new Point(mXPos, mYPos); }
		public function getScale():Number									{ return mScale;			}
		
		// Sets
		public function setAngle(angle:Number):void							{ rotateBody(angle); updateBounds(); drawDebug();}
		public function setLinearVelocity(velocity:Point):void				{	mLinearVelocity = velocity;		}
		public function setAngularVelocity(num:Number):void					{	mAngularVelocity = num;			}
		public function setPosition(newPosX:Number,newPosY:Number):void		{	mXPos = newPosX;	mYPos = newPosY;	}
		public function setCurrentVelocity(velocity:Point):void				{	mCurrentVelocity = velocity;	}
		
		public function getRelativeVelocity(v2:Point, pos2:Point):Number
		{
			var v1:Point = getLinearVelocity();
			var pos1:Point = new Point(getPosition().x+getCenterOfMass().x,getPosition().y+getCenterOfMass().y);
			var distA:Number = Point.distance(pos1, pos2);
			var distB:Number = Point.distance(new Point(pos1.x + v1.x, pos1.y + v1.y), new Point(pos2.x + v2.x, pos2.y + v2.y));
			return distB - distA;
		}
		
		private function getConvexHeight(collPoints:Array):Number
		{
			var minY:Number=0;
			var maxY:Number=0;
			
			for (var i:Number = 0; i < collPoints.length; i++)
			{
				if (minY > collPoints[i].y)
					minY = collPoints[i].y;
				if (maxY < collPoints[i].y)
					maxY = collPoints[i].y;
			}
			
			return maxY - minY;
		}
		
		private function getConvexWidth(collPoints:Array):Number
		{
			var minX:Number=0;
			var maxX:Number=0;
			
			for (var i:Number = 0; i < collPoints.length; i++)
			{
				if (minX > collPoints[i].x)
					minX = collPoints[i].x;
				if (maxX < collPoints[i].x)
					maxX = collPoints[i].x;
			}
			
			return maxX - minX;
		}
		
		/// Tekent de collisionpoints op het scherm
		public function drawDebug():void
		{
			// Draw boundingbox
			mDebugSprite.graphics.lineStyle(0, 0xffffff,0.3);
			mDebugSprite.graphics.beginFill(0xffffff, 0.2);
			mDebugSprite.graphics.moveTo(mBounds.left, mBounds.top);
			mDebugSprite.graphics.lineTo(mBounds.right, mBounds.top);
			mDebugSprite.graphics.lineTo(mBounds.right, mBounds.bottom);
			mDebugSprite.graphics.lineTo(mBounds.left, mBounds.bottom);
			mDebugSprite.graphics.lineTo(mBounds.left, mBounds.top);
			
			mDebugSprite.graphics.lineStyle(1, 0xffffff);
			mDebugSprite.graphics.moveTo(mCollisionPoints[0].x + mXPos, mCollisionPoints[0].y + mYPos);
			
			for (var i:Number = 1; i < mCollisionPoints.length; i++)
			{
				mDebugSprite.graphics.lineTo(mCollisionPoints[i].x+mXPos, mCollisionPoints[i].y+mYPos);
			}
			
			mDebugSprite.graphics.lineTo(mCollisionPoints[0].x + mXPos, mCollisionPoints[0].y + mYPos);
			
			// Draw center of mass
			mDebugSprite.graphics.drawCircle(((mCenterOfMass.x + mXPos)), ((mCenterOfMass.y + mYPos)), 2);
		}
		
		private function updateBounds():void
		{
			var tempBounds:Rectangle = CustomMath.calculateBounds(mCollisionPoints);
			mBounds = new Rectangle(tempBounds.left + mXPos, tempBounds.top + mYPos, tempBounds.width, tempBounds.height);
		}
		
		private function rotateBody(deg:Number):void
		{
			mRotation += deg;
			for (var i:Number = 0; i < mCollisionPoints.length; i++)
			{
				mCollisionPoints[i] = CustomMath.draaiPuntOmPunt(mCollisionPoints[i], deg, mCenterOfMass);
			}
		}
		
		private function inDriehoek(pA:Point, pB:Point, pC:Point, pD:Point):CollisionData
		{
			// Dit point in triangle algoritme is gebaseerd op barycentrische coordinaten
			// Bron: http://www.blackpawn.com/texts/pointinpoly/default.html
			
			var v0:Point = CustomMath.pointSubst(pC,pA);
			var v1:Point = CustomMath.pointSubst(pB, pA);
			var v2:Point = CustomMath.pointSubst(pD, pA);
			
			var dot00:Number = CustomMath.dotProduct(v0, v0);
			var dot01:Number = CustomMath.dotProduct(v0, v1);
			var dot02:Number = CustomMath.dotProduct(v0, v2);
			var dot11:Number = CustomMath.dotProduct(v1, v1);
			var dot12:Number = CustomMath.dotProduct(v1, v2);
			
			var invDenom:Number = 1 / (dot00 * dot11 - dot01 * dot01);
			var vU:Number = (dot11 * dot02 - dot01 * dot12) * invDenom;
			var vV:Number = (dot00 * dot12 - dot01 * dot02) * invDenom;
			
			if ((vU > 0) && (vV > 0) && (vU + vV < 1))
			{	
				// Bereken extra variabelen als het punt in de triangle zit
				var tempImpact:Object = CustomMath.getPointOnSegment(pA, pB, vU + vV);
				var impactPoint:Point = new Point(tempImpact.x, tempImpact.y);
				var cmAngle:Number = Math.atan2(pC.y - pA.y, pC.x - pA.x);
				var impactAngle:Number = Math.atan2(pB.y - pA.y, pB.x - pA.x);
				impactAngle = (cmAngle < impactAngle) ? impactAngle - Math.PI/2 : impactAngle + Math.PI/2;
				
				var intersectSpace:Point = new Point(impactPoint.x-pD.x, impactPoint.y-pD.y);

				return new CollisionData(pD, pA, pB, pC, impactPoint, impactAngle, intersectSpace);
			}
			else
				return null;
		}
		
		private function isIntersectingBody(targetBody:PhysConvexObject):Array
		{
			var output:Array = new Array();
			for (var i:Number = 0; i < targetBody.mCollisionPoints.length; i++)
			{
				var toCheck:Point = new Point(targetBody.getPosition().x + targetBody.mCollisionPoints[i].x, targetBody.getPosition().y + targetBody.mCollisionPoints[i].y);
				
				// Uncomment om slechts 1 keer te checken (voor performance)
				if (CustomMath.rectContainsPoint(mBounds,toCheck) && (mPersistCollCheck || mPersistCollCheck == false))
					var intersectPoint:CollisionData = isIntersecting(toCheck,targetBody);
			}

			return output;
		}
		
		private function isIntersecting(checkPoint:Point,targetBody:PhysConvexObject):CollisionData
		{
			var output:CollisionData;
			
			var collData:Array = new Array();
			
			// Als die vertyfte cones op elkaar zitten moet die ze weer uit elkaar halen
			/*if (targetBody.bodyName != "player" && bodyName != "player")
			{
				var dDistanceX:Number = targetBody.getPosition().x - getPosition().x;
				var dDistanceY:Number = targetBody.getPosition().y - getPosition().y;
				var targetDistance:Number = 10;
				if (dDistanceX < targetDistance)
				{
					targetBody.setPosition(targetBody.getPosition().x+dDistanceX / 4,targetBody.getPosition().y);
					setPosition(getPosition().x - dDistanceX / 4, getPosition().y);
				}
				if (dDistanceY < targetDistance)
				{
					targetBody.setPosition(targetBody.getPosition().x,targetBody.getPosition().y+dDistanceY / 4);
					setPosition(getPosition().x, getPosition().y - dDistanceY / 4);
				}
			}*/
			
			var pC:Point = new Point(getPosition().x+getCenterOfMass().y,getPosition().y+getCenterOfMass().y);
			var pD:Point = checkPoint;
			
			// Voor alle lijnen in mCollisionPoints en alle punten in de targetBody
			for (var i:Number = 1; i < mCollisionPoints.length; i++)
			{
				var pA:Point = new Point(mCollisionPoints[i].x+getPosition().x,mCollisionPoints[i].y+getPosition().y);
				var pB:Point = new Point(mCollisionPoints[i - 1].x+getPosition().x,mCollisionPoints[i-1].y+getPosition().y);
				
				var tempData:CollisionData = inDriehoek(pA, pB, pC, pD);
				
				if (tempData != null)
					collData.push(tempData);
			}
			
			var lpA:Point = new Point(mCollisionPoints[0].x + getPosition().x, mCollisionPoints[0].y + getPosition().y);
			var lpB:Point = new Point(mCollisionPoints[mCollisionPoints.length - 1].x + getPosition().x, mCollisionPoints[mCollisionPoints.length - 1].y + getPosition().y);
			
			var finalData:CollisionData = inDriehoek(lpA, lpB, pC, pD);
			
			if (finalData != null)
				collData.push(tempData);
				
			if (collData.length > 0)
			{
				// Gebruik degene wiens impactAngle het meest overeenkomt
				var tcData:CollisionData = getClosestImpact(targetBody.getLinearVelocity(), collData);
				var relativeVel:Number = getRelativeVelocity(targetBody.getLinearVelocity(), new Point(targetBody.getCenterOfMass().x + targetBody.getPosition().x, targetBody.getCenterOfMass().y + targetBody.getPosition().y));
				if (tcData != null)
				{
					var rollbackX:Number = tcData.intersectionSpace.x;
					var rollbackY:Number = tcData.intersectionSpace.y;
					
					// Rollback to intersection point
					if (targetBody.bodyName != "player")
						targetBody.setPosition(targetBody.getPosition().x + rollbackX, targetBody.getPosition().y + rollbackY);
					else
						setPosition(getPosition().x - rollbackX, getPosition().y - rollbackY);
					
					var iAngle:Number = Math.atan2(tcData.intersectionPoint.y - targetBody.getPosition().y, tcData.intersectionPoint.x - targetBody.getPosition().x);
					
					// DEBUG
					var schietSpeed:Number = 10;
					var richting:Point = Point.polar(schietSpeed, tcData.impactNormal - Math.PI);
					
					var testPoint:Point = new Point(richting.x + tcData.impactPoint.x, richting.y + tcData.impactPoint.y);
					
					if (inDriehoek(tcData.pA, tcData.pB, tcData.pC, testPoint) != null)
					{
						richting.x = -richting.x;
						richting.y = -richting.y;
					}
					
					var deltaAngle:Number = iAngle-tcData.impactNormal;
					var newRotation:Number = deltaAngle * -relativeVel * 0.2;
					
					// Registreer de collision in de hit/miss array
					mPhysWorld.updateScore(tcData.impactPoint.x, tcData.impactPoint.y, targetBody.bodyName, tcData.impactNormal, relativeVel, 5);
					
					if (targetBody.bodyName != "player")
					{
						targetBody.mCurrentVelocity.x = (richting.x/getMass())-targetBody.mLinearVelocity.x * 0.5;
						targetBody.mCurrentVelocity.y = (richting.y/getMass());
						targetBody.setAngularVelocity(newRotation);
					}
					else
					{
						mCurrentVelocity.x = -mCurrentVelocity.x;
						mCurrentVelocity.y = -mCurrentVelocity.y;
					}
				}
			}
				
			//	output = (inConvex) ? new ContactPoint(checkPoint, new Point(0, 0), 0, mLinearVelocity, mCurrentVelocity, bodyName, targetBody.bodyName) : null;
			return output;
		}
		
		private function getClosestImpact(iVel:Point, collData:Array):CollisionData
		{
			var linAngle:Number = CustomMath.normalizeRad(Math.atan2(iVel.y, iVel.x));
			var closestAngle:Number = Math.PI * 4;
			var closestData:CollisionData;
			
			for (var i:Number = 0; i < collData.length; i++)
			{
				if (collData[i] != null)
				{
					var compAngle:Number = -CustomMath.normalizeRad((collData[i].impactNormal) - Math.PI);
					var deltaAngle:Number = compAngle-linAngle;
					
					if (Math.abs(deltaAngle) < closestAngle)
					{
						closestAngle = Math.abs(deltaAngle);
						closestData = collData[i];
					}
				}
			}
			
			return closestData;
		}

		/// Update de positie en rotatie
		public function updateBody():void
		{				
			if ((mLinearVelocity.x != mCurrentVelocity.x) || (mLinearVelocity.y != mCurrentVelocity.y))
			{
				mCurrentVelocity.x = mCurrentVelocity.x + mLinearVelocity.x * mAcceleration;
				mCurrentVelocity.y = mCurrentVelocity.y + mLinearVelocity.y * mAcceleration;
			}
			
			rotateBody(mAngularVelocity);
			
			mXPos += mCurrentVelocity.x;
			
			// Check if inside borders
			var tempYPos:Number = mYPos;
			
			if (tempYPos + (mBounds.height/2) > bottomBorder || tempYPos - (mBounds.height/2) < topBorder)
				mCurrentVelocity.y = (tempYPos - (mBounds.height/2) < topBorder) ? (mCurrentVelocity.y < -1) ? -mCurrentVelocity.y*0.6 : 1 : (tempYPos + (mBounds.height/2) > bottomBorder) ? (mCurrentVelocity.y > 1) ? -mCurrentVelocity.y*0.6 : -1 : 0;

			mYPos += mCurrentVelocity.y;
			
			updateBounds();
			
			drawDebug();
		}
		
		public function rollBackTime(t:Number):void
		{
			mXPos -= mCurrentVelocity.x * t;
			mYPos -= mCurrentVelocity.y * t;
			rotateBody( -mAngularVelocity * t);
			updateBounds();
			drawDebug();
		}
		
		public function handlePreciseCollision(targetBody:PhysConvexObject,intersectArea:Rectangle):void
		{
			var contactPoints:Array = isIntersectingBody(targetBody);
		}
	}
	
}