package int.ai
{
	import flash.display.MovieClip;
	import flash.filters.DisplacementMapFilter;
	import flash.geom.Point;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import int.math.BoundingBox;
	import int.ai.EntityState;
	import int.ai.AnimState;
	import int.ai.RoomManager;
	import int.ai.SpecialWaypointManager;
	import int.ai.AITaskList;
	import int.math.RandomHelper;
	import int.ai.RoomManager;
	import int.ai.Room;
	
	/**
	 * ...
	 * @author Stefan Wijnker
	 */
	
	public class AIEntity extends MovieClip
	{
		// AI Variables
		private var mEntityState:EntityState = new EntityState(EntityState.IDLE);
		private var mAnimState:AnimState = new AnimState(EntityState.IDLE);
		private var mObjectList:Array;
		private var mRoomList:Array;
		private var mFloorList:Array;
		private var mEntityList:Array;
		
		public var mTaskList:AITaskList;
		
		// AI Parameters
		private var mProbVisit:Number = .2; // How likely is it that the entity will check out the audial stimulus when triggered
		private var mVisitMultiplier:Number = .3; // Extra boost on the likelyness to avoid countless clicks
		private var mAudialSensitivity:Number = .6; // How sensitive is this individual entity to sound?
		
		// Movement parameters
		private var mWalkSpeed:Number = 5; // 5 pixels per frame
		private var mVerticalSpeed:Number = 10; // 6 pixels per frame omhoog
		private var mDistance:Number = 10; // Minimale afstand in pixels tussen 2 entities
		private var mOutOfBounds:Number = 800; // Hierbuiten niet updaten!
		private var isWalkingStairs:Boolean = false; // Is de entity bezig met op een trap lopen?
		private var mTimeIdle:Number = 0; // Hoe lang is de entity al niet bang gemaakt?
		private var mAlertedByStimulant:Boolean = false;
		private var mAlertedOnStairway:Boolean = false;
		private var mThreatLocation:Point = new Point();
		private var mRandomRoomTimeOut:Number = 100; // Hoeveel frames zitten ertussen voordat een idle character naar een random kamer gaat?
		private var mScareTimeOut:Number = 300; // Hoeveel frames blijft hij op z'n huidige scare level als die meer dan normaal is?
		
		// DO NOT CHANGE!
		private var reachedDestination:Boolean = false;
		private var arrivedAtDestination:Boolean = true;
		
		public var boundingBox:BoundingBox;
		public var alertedByStimulants:Array = new Array();
		
		public var currentFloor:Number;
		
		public function set currentState(newState:Number):void
		{
			mEntityState.currentState = newState;
		}
		
		/**
		 * The speed of this object to move
		 */
		public function get walkSpeed() : Number
		{
			return mWalkSpeed;
		}
		public function set walkSpeed(value:Number) : void
		{
			mWalkSpeed = value;
		}
		
		/**
		 * The speed of this object when moving up and down stairs.
		 */
		public function get verticalSpeed() :Number
		{
			return mVerticalSpeed;
		}
		public function set verticalSpeed(value:Number) : void
		{
			mVerticalSpeed = value;
		}
		
		/**
		 * The minimum distance between this object and another
		 */
		public function get minDistance() :Number
		{
			return mDistance;
		}
		public function set minDistance(value:Number) : void
		{
			mDistance = value;
		}
		
		/**
		 * This object will stop updating once its out of bounds.
		 * The boundaries are given in pixels.
		 */
		public function get outOfBounds() :Number
		{
			return mOutOfBounds;
		}
		public function set outOfBounds(value:Number) : void
		{
			mOutOfBounds = value;
		}
		
		public function AIEntity()
		{
		}
		
		private function init(floorList:Array,roomList:Array,objectList:Array,entityList:Array) : void 
		{
			addChild(mEntityState);
			mEntityState.addMeter();
			mObjectList = objectList;
			mRoomList = roomList;
			mFloorList = floorList;
			mTaskList = new AITaskList(mObjectList, mRoomList, mFloorList, mEntityList);
			mEntityList = entityList;
			
			// Add bounding box
			boundingBox = new BoundingBox();
			boundingBox.createBoxFromVolume(this);
		}
		
		public function clearTaskList():void
		{
			while (this.mTaskList.taskList.length > 0)
				this.mTaskList.taskList.splice(0, 1);
					
			arrivedAtDestination = true;
			reachedDestination = true;
		}
		
		/**
		 *
		 * @param	strength
		 * @param	stimulantLocation
		 */
		public function alertEntity(strength:Number,stimulantLocation:Point):void
		{
			mProbVisit += strength * Math.random()+mVisitMultiplier;
			var checkItOut:Boolean = (mProbVisit > .5) ? true : false;
			
			// Reset de idle time
			mTimeIdle = 0;
			
			// AIEntity was alerted, so clear the current task list
			if (this.mTaskList.taskList.length > 0 && this.mEntityState.currentState < EntityState.HYSTERICAL)
			{
				if (isWalkingStairs)
				{
					mAlertedOnStairway = true;
					mThreatLocation = stimulantLocation;
				}
				else 
				{
					clearTaskList();
				}
			}
			
			// ONLY go to the position when the tasklist is empty, else horrible fail will occur
			if (checkItOut && isWalkingStairs == false && this.mTaskList.taskList.length == 0)
			{
				updateScare(stimulantLocation);
			}
		}
		
		public function updateScare(threatLocation:Point):void
		{
				if (this.mEntityState.currentState < EntityState.HYSTERICAL)
				{
				// Set back the mProbVisit
				mProbVisit = .1;
				mAlertedByStimulant = true;
				var gotoRoomNr:Number = RoomManager.getRoomAtPosition(threatLocation.x, threatLocation.y, mFloorList, mRoomList);
				mTaskList.gotoRoom(	gotoRoomNr,
									this,
									mEntityList,
									RandomHelper.generateRandomInRange(threatLocation.x, 20));
				}
				else 
				{
					// Get the room on the most bottom right of the screen on floor 1
					var outValue:Number = 0;
					var outRoom:Room;
					for (var rN:Number = 0; rN < mRoomList.length; rN++)
					{
						
						if (mRoomList[rN].floor == 0)
						{
							if (mRoomList[rN].rightBorder > outValue)
							{	
								outValue = mRoomList[rN].rightBorder;
								outRoom = mRoomList[rN];
							}
						}
					}
					
					// SCREAM! (Wilhelm scream lol)
					var soundChannel:SoundChannel = new SoundChannel();
					var screamSfx:Sound = new wilhelmScreamSfx();
					soundChannel = screamSfx.play();
					
					// Meer punten erbij
					MovieClip(this.parent.parent.parent).gameState.ectoScore += MovieClip(this.parent.parent.parent).victimScore;
					
					// Ren het scherm uit gek
					mTaskList.gotoRoom(outRoom.roomType, this, mEntityList, 900);
				}
		}
		
		public function showInfo() : void
		{
				trace("AIEntityInfo");
				trace("------------------");
				trace("Current status: " + this.currentLabel.toUpperCase());
				trace("Visit probability on next stimulation: " + mProbVisit);
				trace("Current AITaskList length: " + mTaskList.taskList.length);
				trace("Arrived at destination: " + arrivedAtDestination);
					if (mTaskList.taskList.length > 0)
					{
						trace("Current target X: " + mTaskList.taskList[0].targetX);
						trace("Current target floor: " + mTaskList.taskList[0].targetFloor);
					}
				trace("Current floor: " + currentFloor);
				trace("Current x position: " + this.x);
				trace("Current y position: " + this.y);
				trace("------------------");
		}
		
		public function update() : void
		{
			if(this.mTaskList.taskList.length == 0)
				mTimeIdle++;
				
			if (mTimeIdle >= mRandomRoomTimeOut && mEntityState.currentState < EntityState.HYSTERICAL)
			{
				mTaskList.gotoRandomRoom(this);
				//mRandomRoomTimeOut = 0;
				mTimeIdle = 0;
			}

			mEntityState.updateState();
			
			if (this.x < mOutOfBounds)
			{
				boundingBox.updateBox(this);
				
				// If there's something to do
				if (mTaskList.taskList.length != 0)
				{
					arrivedAtDestination = false;
					// Handle off the next waypoint on the list
					var dX:Number = mTaskList.taskList[0].targetX - this.x;
					var dY:Number = mFloorList[mTaskList.taskList[0].targetFloor].floorY - this.y;
					
						if (dY<1 && dY>-1)
						{
							isWalkingStairs = false;
							if (dX >= mWalkSpeed)
							{
								this.x += mWalkSpeed;
								this.scaleX = -1;
							}
							else if (dX <= -mWalkSpeed)
							{
								this.x -= mWalkSpeed;
								this.scaleX = 1;
							}
						}
						else 
						{
							isWalkingStairs = true;
							// Has to move down a floor
							// Calculate angle between entity and end point
							var dirAngle:Number = Math.atan2(dY, dX)/Math.PI*180;
							this.x += Math.cos(dirAngle * Math.PI / 180) * mWalkSpeed;
							this.scaleX = (Math.cos(dirAngle * Math.PI / 180) * mWalkSpeed > 0) ? -1 : 1;
							this.y += Math.sin(dirAngle * Math.PI / 180) * mWalkSpeed;
						}
						
						if ((dX < mWalkSpeed && dX > -mWalkSpeed) && (dY > -mWalkSpeed && dY < mWalkSpeed)) 
							reachedDestination = true;
						else 
							reachedDestination = false;
						
						if(reachedDestination)
						{	
							isWalkingStairs = false;
							arrivedAtDestination = (mTaskList.taskList.length > 0) ? false: true;
							mTimeIdle = (arrivedAtDestination) ? 0: mTimeIdle;
							mEntityState.updateState();
							
							this.x = mTaskList.taskList[0].targetX;
							this.y = mFloorList[mTaskList.taskList[0].targetFloor].floorY;
							
							if (mAlertedOnStairway)
							{
								clearTaskList();
								mAlertedOnStairway = false;
								updateScare(mThreatLocation);
							}
							
							this.currentFloor = mTaskList.taskList[0].targetFloor;
							mTaskList.removeAITask(0);
							
							// If they reached their destination, put them back on idle
							if (mTaskList.taskList.length == 0)
							{
								// Check if there are overlapping entities
								var distance:Number;
								var tooClose:Boolean = false;
								for (var entityOverlap:Number = 0; entityOverlap < mEntityList.length; entityOverlap++)
								{
									// Only check those on same floor, 
									if (mEntityList[entityOverlap].currentFloor == currentFloor && 
										mEntityList[entityOverlap] != this && 
										mEntityList[entityOverlap].mTaskList.taskList.length == 0)
									{
										 distance = this.x - mEntityList[entityOverlap].x;
										 distance = (distance < 0) ? -distance : distance;
										 
										 if (distance < mDistance)
										 {
											 tooClose = true;
										 }
									}
								}
								
								if (tooClose)
								{
									var currentRoom:Room = RoomManager.getRoomAtFloor(this.x, currentFloor, mRoomList);
									 
									 // While the position is taken, generate another 
									var newXPos:Number = RoomManager.generatePositionInRoom(currentRoom, mDistance);
									
									while (RoomManager.isTakenPos(newXPos, currentFloor, this, mEntityList, mDistance))
									{	
										newXPos = RoomManager.generatePositionInRoom(currentRoom, mDistance);
									}
									//trace("tooClose");
									 mTaskList.addAITask(newXPos, currentFloor);
								}
								else {
									// Aaaaaiiit hij staat goed jeweetzelluf
									if (mAlertedByStimulant)
									{
										mEntityState.currentState++;
										mAlertedByStimulant = false;
									}
									mEntityState.updateState();
								}
							}
						}
						
				}
				else 
				{
					arrivedAtDestination = true;
				}
						// Update animations
						if (arrivedAtDestination)
						{
			
							if (mTimeIdle > mScareTimeOut && mEntityState.currentState > EntityState.IDLE)
							{
								mEntityState.currentState--;
								mEntityState.updateState();
								mTimeIdle = 0;
							}
							
							switch(mEntityState.currentState)
							{
								case EntityState.IDLE:
									if(this.currentLabel != AnimState.IDLE_ANIM)
										this.gotoAndStop(AnimState.IDLE_ANIM);
									break;
								case EntityState.AFRAID:
									if(this.currentLabel != AnimState.AFRAID_ANIM)
										this.gotoAndStop(AnimState.AFRAID_ANIM);
									break;
								case EntityState.SCARED:
									if(this.currentLabel != AnimState.SCARED_ANIM)
										this.gotoAndStop(AnimState.SCARED_ANIM);
									break;
								case EntityState.HYSTERICAL:
									if (this.currentLabel != AnimState.HYSTERICAL_ANIM)
										this.gotoAndStop(AnimState.HYSTERICAL_ANIM);
									break;
								default:
									if (this.currentLabel != AnimState.IDLE_ANIM)
										this.gotoAndStop(AnimState.IDLE_ANIM);
									break;
							}
						}
						else 
						{
							if (mEntityState.currentState < EntityState.HYSTERICAL)
							{
								if (this.currentLabel != AnimState.WALKING_ANIM)
									this.gotoAndStop(AnimState.WALKING_ANIM);
							}
							else 
							{
								if (this.currentLabel == AnimState.HYSTERICAL_ANIM)
									this.gotoAndStop(AnimState.WALKING_HYST);
							}
						}
			}
			else {
				// Remove entity from entity list
				MovieClip(this.parent).removeEntity(this);
			}
		}
	}
	
}