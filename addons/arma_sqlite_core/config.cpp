class CfgPatches {
    class arma_sqlite_core {
        name = "Arma SQLite Core";
        author = "FunnyCookieEver";
        requiredVersion = 2.10;
        requiredAddons[] = {"A3_Functions_F"};
        units[] = {};
        weapons[] = {};
        version = "1.0.0";
        versionAr[] = {1, 0, 0};
    };
};

class CfgFunctions {
    class A3SQL {
        tag = "A3SQL";
        class Core {
            file = "\a3sql\core\functions";
            class preInit { preInit = 1; };
            class postInit { postInit = 1; };
            class startup {};
            class waitReady {};
            class raw {};
            class collect {};
            class check {};
            class call {};
            class submit {};
            class await {};
            class async {};
            class unhex {};
            class cell {};
            class rows {};
            class query {};
            class exec {};
            class smokeTest {};
        };
    };
};
