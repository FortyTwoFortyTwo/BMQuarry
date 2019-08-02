#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#pragma newdecls required

#define MAX_SIZE	15	//15x15 func_breakable
#define MAX_HEIGHT	13	//13 blocks underneath until reaches lava, not counting first floor with already placed blocks

//coords to start placing blocks
#define START_X		-896.0
#define START_Y		-896.0
#define START_Z		-448.0

#define BLOCK_SIZE	128.0	//Size of a single block in hu

#define BRUSH_TEMPLATE	"spawn_template"	//point_template targetname to clone

enum blockStatus
{
	blockStatus_NotSpawned,
	blockStatus_Spawned,
	blockStatus_Break
}

blockStatus g_iGrid[MAX_SIZE][MAX_SIZE][MAX_HEIGHT];
int g_iEntityRef[MAX_SIZE][MAX_SIZE][MAX_HEIGHT];
int g_iSpawnCoord[3];
bool g_bIsQuarryMap;

public Plugin myinfo =
{
    name = "BM Quarry helper",
    author = "42",
    description = "Because making logics in hammer is garbage",
    version = "0.0.0",
    url = "https://github.com/FortyTwoFortyTwo/BMQuarry"
}

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
}

public void OnMapStart()
{
	char sMap[256];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));
	
	if (StrContains(sMap, "bm_quarry") == 0)
		g_bIsQuarryMap = true;
	else
		g_bIsQuarryMap = false;
}

public Action Event_RoundStart(Handle hEvent, const char[] name, bool dontBroadcast)
{
	if (!g_bIsQuarryMap) return;
	
	//Reset all of the shits
	for (int i = 0; i < sizeof(g_iSpawnCoord); i++)
		g_iSpawnCoord[i] = -1;
	
	for (int x = 0; x < MAX_SIZE; x++)
	{
		for (int y = 0; y < MAX_SIZE; y++)
		{
			for (int z = 0; z < MAX_HEIGHT; z++)
			{
				if (z == 0)
				{
					//Create starting platorm at top
					CreateBreakable(x, y, z);
				}
				else
				{
					//Empty platorm at bottom
					g_iGrid[x][y][z] = blockStatus_NotSpawned;
					g_iEntityRef[x][y][z] = 0;
				}
			}
		}
	}	
}

public void OnEntityCreated(int iEntity, char[] sClassname)
{
	if (!g_bIsQuarryMap) return;
	
	if (StrEqual(sClassname, "func_breakable"))
	{
		for (int i = 0; i < sizeof(g_iSpawnCoord); i++)
			if (g_iSpawnCoord[i] < 0)
				return;
		
		HookSingleEntityOutput(iEntity, "OnBreak", OnBreakableBreak, true);
		
		g_iGrid[g_iSpawnCoord[0]][g_iSpawnCoord[1]][g_iSpawnCoord[2]] = blockStatus_Spawned;
		g_iEntityRef[g_iSpawnCoord[0]][g_iSpawnCoord[1]][g_iSpawnCoord[2]] = EntIndexToEntRef(iEntity);
		
		for (int i = 0; i < sizeof(g_iSpawnCoord); i++)
			g_iSpawnCoord[i] = -1;
	}
}

public void OnBreakableBreak(const char[] sOutput, int iBreakable, int iActivator, float flDelay)
{
	//Find coord breakable came from
	int iRef = EntIndexToEntRef(iBreakable);
	int x, y, z;
	
	for (x = 0; x < MAX_SIZE; x++)
	{
		for (y = 0; y < MAX_SIZE; y++)
		{
			for (z = 0; z < MAX_HEIGHT; z++)
			{
				if (iRef == g_iEntityRef[x][y][z])
				{
					g_iGrid[x][y][z] = blockStatus_Break;
					g_iEntityRef[x][y][z] = 0;
					
					//Check all 6 sides, see if there spot to create
					if (x > 0 				&& g_iGrid[x-1][y][z] == blockStatus_NotSpawned) CreateBreakable(x-1, y, z);
					if (x < MAX_SIZE-1		&& g_iGrid[x+1][y][z] == blockStatus_NotSpawned) CreateBreakable(x+1, y, z);
					if (y > 0				&& g_iGrid[x][y-1][z] == blockStatus_NotSpawned) CreateBreakable(x, y-1, z);
					if (y < MAX_SIZE-1		&& g_iGrid[x][y+1][z] == blockStatus_NotSpawned) CreateBreakable(x, y+1, z);
					if (z > 0				&& g_iGrid[x][y][z-1] == blockStatus_NotSpawned) CreateBreakable(x, y, z-1);
					if (z < MAX_HEIGHT-1	&& g_iGrid[x][y][z+1] == blockStatus_NotSpawned) CreateBreakable(x, y, z+1);
					
					return;
				}
			}
		}
	}
}

void CreateBreakable(int x, int y, int z)
{
	//Since we cant create brushes in Sourcemod, we clone existing brush in map using point_template and env_entity_maker
	
	int iEntityMaker = CreateEntityByName("env_entity_maker");
	if (iEntityMaker > MaxClients)
	{
		DispatchKeyValue(iEntityMaker, "EntityTemplate", BRUSH_TEMPLATE);
		DispatchSpawn(iEntityMaker);
		
		float flCoord[3];
		flCoord[0] = START_X + float(x) * BLOCK_SIZE;
		flCoord[1] = START_Y + float(y) * BLOCK_SIZE;
		flCoord[2] = START_Z - float(z) * BLOCK_SIZE;
		
		TeleportEntity(iEntityMaker, flCoord, NULL_VECTOR, NULL_VECTOR);
		
		g_iSpawnCoord[0] = x;
		g_iSpawnCoord[1] = y;
		g_iSpawnCoord[2] = z;
		AcceptEntityInput(iEntityMaker, "ForceSpawn");
		AcceptEntityInput(iEntityMaker, "Kill");
	}
}