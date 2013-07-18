module semargl.RightTypeDef;

public static char* rt_symbols = "crwuda";

enum RightType
{
	CREATE = 0,
	READ = 1,
	WRITE = 2,
	UPDATE = 3,
	DELETE = 4,
	ADMIN = 5	
}