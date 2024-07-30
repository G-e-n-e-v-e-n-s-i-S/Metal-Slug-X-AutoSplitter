


state("mslugx")
{

}

state("WinKawaks")
{
	int pointerScreen : 0x0046B270;
}

state("fcadefbneo")
{
	int pointerScreen : 0x02D73FD0, 0x4, 0xF4;
	//int pointerScreen : 0x02D4D8D4, 0x4, 0x4, 0x14;
}





startup
{
	
	//A function that finds an array of bytes in memory
	Func<Process, SigScanTarget, IntPtr> FindArray = (process, target) =>
	{

		IntPtr pointer = IntPtr.Zero;
		
		foreach (var page in process.MemoryPages())
		{

			var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);

			pointer = scanner.Scan(target);

			if (pointer != IntPtr.Zero) break;

		}
		
		return pointer;

	};

	vars.FindArray = FindArray;



	//A function that reads an array of 60 bytes in the screen memory
	Func<Process, int, byte[]> ReadArray = (process, offset) =>
	{

		byte[] bytes = new byte[60];

		bool succes = ExtensionMethods.ReadBytes(process, vars.pointerScreen + offset, 60, out bytes);

		if (!succes)
		{
			print("[MSX AutoSplitter] Failed to read screen");
		}

		return bytes;

	};

	vars.ReadArray = ReadArray;



	//A function that matches two arrays of bytes
	Func<byte[], byte[], bool> MatchArray = (bytes, colors) =>
	{

		if (bytes == null)
		{
			return false;
		}

		for (int i = 0; i < bytes.Length && i < colors.Length; i++)
		{

			if (bytes[i] != colors[i])
			{
				return false;
			}
		}

		return true;

	};

	vars.MatchArray = MatchArray;



	//A function that prints an array of bytes
	Action<byte[]> PrintArray = (bytes) =>
	{

		if (bytes == null)
		{
			print("[MSX AutoSplitter] Bytes are null");
		}

		else
		{
			var str = new System.Text.StringBuilder();

			for (int i = 0; i < bytes.Length; i++)
			{
				str.Append(bytes[i].ToString());

				str.Append(",");

				if (i % 4 == 3) str.Append("\n");

				else str.Append("\t");
			}

			print(str.ToString());
		}
	};

	vars.PrintArray = PrintArray;

	

	//Should we reset and restart the timer
	vars.restart = false;



	//The time at which the last reset happenend
	vars.prevRestartTime = Environment.TickCount;



	//An array of bytes to find the screen's pixel array memory region
	vars.scannerTargetScreen = new SigScanTarget(0, "10 08 00 00 ?? ?? 00 ?? ?? ?? ?? 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 20");



	//The pointer to the screen's pixel array memory region, once we found it with the scan
	vars.pointerScreen = IntPtr.Zero;



	//A watcher for this pointer
	vars.watcherScreen = new MemoryWatcher<short>(IntPtr.Zero);

	vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;



	//The time at which the last scan for the screen region happenend
	vars.prevScanTimeScreen = -1;



	//An array of bytes to find the boss's health variable
	vars.scannerTargetBossHealth = new SigScanTarget(22, "10 00 B6 D7 ?? 00 ?? ?? ?? ?? ?? ?? ?? 00 ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 04 00 E4 4D");



	//The pointer to the boss's health, once we found it with the scan
	vars.pointerBossHealth = IntPtr.Zero;



	//A watcher for this pointer
	vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);



	//The time at which the last scan happenend
	vars.prevScanTimeBossHealth = -1;



	//The time at which the last split happenend
	vars.prevSplitTime = -1;



	//The split/state we are currently on
	vars.splitCounter = 0;
	

	
	//A local tickCount to do stuff sometimes
	vars.localTickCount = 0;

}





init
{
	
	//Set refresh rate
	refreshRate = 60;


	/*
	 * 
	 * The various color arrays we will be checking for throughout the game
	 * Colors must be formated as : Blue, Green, Red, Alpha
	 *
	 * On the Steam version, Alpha seems to always be 255
	 * On the Steam version, the offset is 0x40 + X * 0x4 + Y * 0x800
	 *
	 * On the WinKawaks version, Alpha seems to always be 0
	 * On the WinKawaks version, the offset is X * 0x4 + Y * 0x500
	 * 
	 */
	if(game.ProcessName.Equals("WinKawaks"))
	{
		
		//The footsteps in the sand when the character hits the ground at the start of mission 1
		//Starts at pixel ( 104 , 147 )
		vars.colorsRunStart = new byte[]		{
													192, 112, 112, 0,
													152, 80,  88,  0,
													104, 56,  64,  0,
													128, 72,  72,  0,
													152, 80,  88,  0,
													152, 80,  88,  0,
													176, 96,  96,  0,
													176, 96,  96,  0,
													176, 96,  96,  0,
													192, 112, 112, 0
												};
		
		vars.offsetRunStart = 0x2BBE0;
		
		
		
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,   0,   0,   0,
													248, 248, 248, 0,
													0,   0,   120, 0,
													48,  208, 248, 0,
													24,  144, 248, 0,
													48,  208, 248, 0,
													24,  144, 248, 0,
													48,  208, 248, 0,
													248, 248, 248, 0,
													0,   0,   0,   0
												};

		vars.offsetExclamationMark = 0x21C9C;
		
		

		//The grey of the UI
		//Starts at pixel ( 80 , 8 ) for player 1
		//Starts at pixel ( 176 , 8 ) for player 2
		vars.colorsUI = new byte[]				{
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0
												};

		vars.offsetUI = 0x2740;
		
		vars.offsetUI2 = 0x28C0;
		
		
		
		//The rim of Rugname when it hits the ground after phase 1
		//Starts at pixel ( 159 , 159 )
		vars.colorsBossStart = new byte[]		{
													88, 104, 104, 0,
													88, 104, 104, 0,
													88, 104, 104, 0,
													88, 104, 104, 0,
													88, 104, 104, 0,
													88, 104, 104, 0,
													88, 104, 104, 0,
													88, 104, 104, 0,
													88, 104, 104, 0,
													88, 104, 104, 0
												};

		vars.offsetBossStart = 0x2F5BC;

	}



	else if (game.ProcessName.Equals("fcadefbneo"))
	{
		
		//The footsteps in the sand when the character hits the ground at the start of mission 1
		//Starts at pixel ( 104 , 147 )
		vars.colorsRunStart = new byte[]		{
													198, 115, 115, 0,
													198, 115, 115, 0,
													156, 82,  90,  0,
													156, 82,  90,  0,
													107, 57,  66,  0,
													107, 57,  66,  0,
													132, 74,  74,  0,
													132, 74,  74,  0,
													156, 82,  90,  0,
													156, 82,  90,  0,
													156, 82,  90,  0,
													156, 82,  90,  0,
													181, 99,  99,  0,
													181, 99,  99,  0,
													181, 99,  99,  0
												};
		
		vars.offsetRunStart = 0xAEC40;
		
		
		
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,   0,   0,   0,
													0,   0,   0,   0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													0,   0,   123, 0,
													0,   0,   123, 0,
													49,  214, 255, 0,
													49,  214, 255, 0,
													24,  148, 255, 0,
													24,  148, 255, 0,
													49,  214, 255, 0,
													49,  214, 255, 0,
													24,  148, 255, 0,
													24,  148, 255, 0,
													49,  214, 255, 0
												};

		vars.offsetExclamationMark = 0x86AB8;
		
		

		//The grey of the UI
		//Starts at pixel ( 80 , 8 ) for player 1
		//Starts at pixel ( 176 , 8 ) for player 2
		vars.colorsUI = new byte[]				{
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0
												};

		vars.offsetUI = 0x9A80;
		
		vars.offsetUI2 = 0x9D80;
		
		
		
		//The rim of Rugname when it hits the ground after phase 1
		//Starts at pixel ( 159 , 159 )
		vars.colorsBossStart = new byte[]		{
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0,
													90, 107, 107, 0
												};
		
		vars.offsetBossStart = 0xBD1F8;

	}



	else //if(game.ProcessName.Equals("mslugx"))
	{
		
		//The footsteps in the sand when the character hits the ground at the start of mission 1
		//Starts at pixel ( 104 , 147 )
		vars.colorsRunStart = new byte[]		{
													198, 113, 115, 255,
													156, 81,  90,  255,
													107, 56,  66,  255,
													132, 73,  74,  255,
													156, 81,  90,  255,
													156, 81,  90,  255,
													181, 97,  99,  255,
													181, 97,  99,  255,
													181, 97,  99,  255,
													198, 113, 115, 255
												};
		
		vars.offsetRunStart = 0x499CF;
	
		

		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,   0,   0,   255,
													255, 251, 255, 255,
													0,   0,   123, 255,
													49,  211, 255, 255,
													24,  146, 255, 255,
													49,  211, 255, 255,
													24,  146, 255, 255,
													49,  211, 255, 255,
													255, 251, 255, 255,
													0,   0,   0,   255
												};

		vars.offsetExclamationMark = 0x38C0B;

		

		//The grey of the UI
		//Starts at pixel ( 80 , 8 ) for player 1
		//Starts at pixel ( 176 , 8 ) for player 2
		vars.colorsUI = new byte[]				{
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255
												};

		vars.offsetUI = 0x416F;
		
		vars.offsetUI2 = 0x42EF;
		

		
		//The rim of Rugname when it hits the ground after phase 1
		//Starts at pixel ( 159 , 159 )
		vars.colorsBossStart = new byte[]		{
													90,  105, 107, 255,
													90,  105, 107, 255,
													90,  105, 107, 255,
													90,  105, 107, 255,
													90,  105, 107, 255,
													90,  105, 107, 255,
													90,  105, 107, 255,
													90,  105, 107, 255,
													90,  105, 107, 255,
													90,  105, 107, 255
												};
		
		vars.offsetBossStart = 0x4FAAB;
		
	}
}





exit
{

	//The pointers and watchers are no longer valid
	vars.pointerScreen = IntPtr.Zero;
	
	vars.watcherScreen = new MemoryWatcher<short>(IntPtr.Zero);

	vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	vars.pointerBossHealth = IntPtr.Zero;

	vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);

}





update
{
	
	//Increase local tickCount
	vars.localTickCount = vars.localTickCount + 1;



	//Try to find the screen
	//For Kawaks and FightCade, follow the pointer path
	if(game.ProcessName.Equals("WinKawaks") || game.ProcessName.Equals("fcadefbneo"))
	{
		vars.pointerScreen = new IntPtr(current.pointerScreen);
	}
	
	//For Steam, do a scan
	else
	{

		//If the screen region changed place in memory
		vars.watcherScreen.Update(game);
		
		if (vars.watcherScreen.Changed)
		{
			
			//Void the pointer
			vars.pointerScreen = IntPtr.Zero;

		}

		
		
		//If the screen pointer is void
		if (vars.pointerScreen == IntPtr.Zero)
		{
		
			//If the screen scan cooldown has elapsed
			var timeSinceLastScan = Environment.TickCount - vars.prevScanTimeScreen;
	
			if (timeSinceLastScan > 300)
			{
				
				//Notify
				print("[MSX AutoSplitter] Scanning for screen");



				//Scan for the screen
				vars.pointerScreen = vars.FindArray(game, vars.scannerTargetScreen);
			
			
		
				//If the scan was successful
				if (vars.pointerScreen != IntPtr.Zero)
				{
					
					//Notify
					print("[MSX AutoSplitter] Found screen");



					//Create a new memory watcher
					vars.watcherScreen = new MemoryWatcher<short>(vars.pointerScreen);

					vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

				}
			
			
			
				//Write down scan time
				vars.prevScanTimeScreen = Environment.TickCount;
			
			}
		}
	}
	
	

	//If we know where the screen is
	if (vars.pointerScreen != IntPtr.Zero)
	{
		
		//Debug print
		/*
		if (vars.localTickCount % 10 == 0)
		{
			print("[MSX AutoSplitter] Debug " + vars.splitCounter.ToString());
			
			vars.PrintArray(vars.ReadArray(game, vars.offsetRunStart));
		}
		*/

		
	
		//Check time since last reset, don't reset if we already reset in the last second
		var timeSinceLastReset = Environment.TickCount - vars.prevRestartTime;
		
		if (timeSinceLastReset< 1000)
		{
			vars.restart = false;
		}
		
		//Otherwise, check if we should start/restart the timer
		else
		{
			vars.restart = vars.MatchArray(vars.ReadArray(game, vars.offsetRunStart), vars.colorsRunStart);
		}
	}
}





reset
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
		vars.prevRestartTime = Environment.TickCount;

		vars.prevSplitTime = -1;
		
		vars.prevScanTimeScreen = -1;

		vars.prevScanTimeBossHealth = -1;
		
		vars.pointerBossHealth = IntPtr.Zero;

		vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);

		return true;
	}
}





start
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
		vars.prevRestartTime = Environment.TickCount;

		vars.prevSplitTime = -1;
		
		vars.prevScanTimeScreen = -1;

		vars.prevScanTimeBossHealth = -1;
		
		vars.pointerBossHealth = IntPtr.Zero;

		vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);
		
		return true;
	}
}





split
{
	
	//Check time since last split, don't split if we already split in the last 20 seconds
	var timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;
	
	if (vars.prevSplitTime != -1 && timeSinceLastSplit < 20000)
	{
		return false;
	}
	
	
	
	//If we dont know where the screen is, stop
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}



	//Missions 1, 2, 3, 4 and 5
	if (vars.splitCounter < 10)
	{
		
		if (vars.splitCounter % 2 == 0)
		{
			
			//Check for the exclamation mark from the "Mission Complete !" text
			byte[] pixels = vars.ReadArray(game, vars.offsetExclamationMark);
			
			if (vars.MatchArray(pixels, vars.colorsExclamationMark))
			{
				vars.splitCounter++;
			}
		}

		else
		{
			
			//Split when the UI disappears for both players after we've seen the exclamation mark
			byte[] pixels = vars.ReadArray(game, vars.offsetUI);

			byte[] pixels2 = vars.ReadArray(game, vars.offsetUI2);
			
			if (!vars.MatchArray(pixels, vars.colorsUI) && !vars.MatchArray(pixels2, vars.colorsUI))
			{
				vars.splitCounter++;
			
				vars.prevSplitTime = Environment.TickCount;
			
				return true;
			}
		}
	}



	//Knowing when we get to the last phase of the last boss
	else if (vars.splitCounter == 10)
	{
		
		//When Rugname hits the ground
		byte[] pixels = vars.ReadArray(game, vars.offsetBossStart);
	
		if (vars.MatchArray(pixels, vars.colorsBossStart))
		{
			
			//Clear the pointer to the boss's health
			vars.pointerBossHealth = IntPtr.Zero;
			
			
			
			//Move to next phase, prevent splitting/scanning for 20 seconds (but don't actually split)
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
		}
	}



	//Finding the boss's health variable
	else if (vars.splitCounter == 11)
	{
		
		//Check time since last scan, don't scan if we already scanned in the last 8 seconds
		//This should end up triggering about 2 or 3 times, which should be more than enough to find his health before the end of the fight
		var timeSinceLastScan = Environment.TickCount - vars.prevScanTimeBossHealth;
		
		if (timeSinceLastScan > 8000)
		{
			
			//Notify
			print("[MSX AutoSplitter] Scanning for health");



			//Scan
			vars.pointerBossHealth = vars.FindArray(game, vars.scannerTargetBossHealth);
			
			
		
			//If the scan was successful
			if (vars.pointerBossHealth != IntPtr.Zero)
			{
				
				//Notify
				print("[MSX AutoSplitter] Found health");
				
				
				
				//Create a new memory watcher
				vars.watcherBossHealth = new MemoryWatcher<short>(vars.pointerBossHealth);

				vars.watcherBossHealth.Update(game);
				
				
				
				//Move to next phase
				vars.splitCounter++;

			}
			
			
			
			//Write down scan time
			vars.prevScanTimeBossHealth = Environment.TickCount;
	
		}
	}



	//Check that the boss's health has been reset above 0
	else if (vars.splitCounter == 12)
	{
		
		vars.watcherBossHealth.Update(game);
		
		if (vars.watcherBossHealth.Current > 0)
		{
			
			//Go to next phase
			vars.splitCounter++;

		}
	}



	//Check that the boss's health has been reduced to 0
	else if (vars.splitCounter == 13)
	{

		//Update watcher
		vars.watcherBossHealth.Update(game);
		
		
		
		//Split when the boss's health reaches 0
		if (vars.watcherBossHealth.Current == 0)
		{
			vars.splitCounter++;

			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}
}
