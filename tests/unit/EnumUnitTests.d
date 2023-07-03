/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 24, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;
import dstep.translator.Translator;

// Test standard enum.
unittest
{
    assertTranslates(
q"C
enum Qux
{
    FOO,
    BAR,
    BAZ,
};
C",
q"D
extern (C):

enum Qux
{
    FOO = 0,
    BAR = 1,
    BAZ = 2
}
D");

}


// Test typedefed enum.
unittest
{
assertTranslates(
q"C
typedef enum
{
    FOO,
    BAR,
    BAZ,
} Qux;
C",
q"D
extern (C):

enum Qux
{
    FOO = 0,
    BAR = 1,
    BAZ = 2
}
D");

}

// Test named enum with immediate variable declaration.
unittest
{
    assertTranslates(
q"C
enum Qux
{
    FOO,
    BAR,
    BAZ,
} qux;
C",
q"D
extern (C):

enum Qux
{
    FOO = 0,
    BAR = 1,
    BAZ = 2
}

extern __gshared Qux qux;
D");

}

// Test anonymous enum with immediate variable declaration.
unittest
{
    assertTranslates(
q"C
enum
{
    FOO,
    BAR,
    BAZ,
} qux;
C",
q"D
extern (C):

enum _Anonymous_0
{
    FOO = 0,
    BAR = 1,
    BAZ = 2
}

alias FOO = _Anonymous_0.FOO;
alias BAR = _Anonymous_0.BAR;
alias BAZ = _Anonymous_0.BAZ;

extern __gshared _Anonymous_0 qux;
D");

}

// Test anonymous enum.
unittest
{
assertTranslates(
q"C
enum
{
    FOO,
    BAR,
    BAZ,
};
C",
q"D
extern (C):

enum
{
    FOO = 0,
    BAR = 1,
    BAZ = 2
}
D");

}

// Test an anonymous enum inside a struct.
unittest
{
    assertTranslates(
q"C
struct Struct
{
    enum
    {
        FOO,
        BAR,
        BAZ,
    };
};
C",
q"D
extern (C):

struct Struct
{
    enum _Anonymous_0
    {
        FOO = 0,
        BAR = 1,
        BAZ = 2
    }
}

alias FOO = Struct._Anonymous_0.FOO;
alias BAR = Struct._Anonymous_0.BAR;
alias BAZ = Struct._Anonymous_0.BAZ;

D");

}

// Test an anonymous enum inside a struct with an immediate variable declaration.
unittest
{
    assertTranslates(
q"C
struct Struct
{
    enum
    {
        FOO,
        BAR,
        BAZ,
    } qux;
};
C",
q"D
extern (C):

struct Struct
{
    enum _Anonymous_0
    {
        FOO = 0,
        BAR = 1,
        BAZ = 2
    }

    _Anonymous_0 qux;
}

alias FOO = Struct._Anonymous_0.FOO;
alias BAR = Struct._Anonymous_0.BAR;
alias BAZ = Struct._Anonymous_0.BAZ;

D");

}

// Test aliasing of all enum members.
unittest
{
    Options options;
    options.aliasEnumMembers = true;

    assertTranslates(
q"C
enum Enum
{
    FOO,
    BAR,
    BAZ,
};
C",
q"D
extern (C):

enum Enum
{
    FOO = 0,
    BAR = 1,
    BAZ = 2
}

alias FOO = Enum.FOO;
alias BAR = Enum.BAR;
alias BAZ = Enum.BAZ;
D", options);

}

// Test aliasing of all enum members in nested scope
unittest
{
    Options options;
    options.aliasEnumMembers = true;

    assertTranslates(
q"C
enum Enum
{
    FOO,
};

struct Foo
{
    enum FooEnum
    {
        BAR,
        BAZ,
    } fooEnum;

    enum BarEnum
    {
        QUX
    } barEnum;
};
C",
q"D
extern (C):

enum Enum
{
    FOO = 0
}

alias FOO = Enum.FOO;

struct Foo
{
    enum FooEnum
    {
        BAR = 0,
        BAZ = 1
    }

    FooEnum fooEnum;

    enum BarEnum
    {
        QUX = 0
    }

    BarEnum barEnum;
}

alias BAR = Foo.FooEnum.BAR;
alias BAZ = Foo.FooEnum.BAZ;
alias QUX = Foo.BarEnum.QUX;
D", options);

}

// Test aliasing of all enum members for anonymous typedefed enum.
unittest
{
    Options options;
    options.aliasEnumMembers = true;

    assertTranslates(
q"C
typedef enum
{
    FOO,
    BAR,
    BAZ,
} Enum;
C",
q"D
extern (C):

enum Enum
{
    FOO = 0,
    BAR = 1,
    BAZ = 2
}

alias FOO = Enum.FOO;
alias BAR = Enum.BAR;
alias BAZ = Enum.BAZ;
D", options);
}

// Test a named enum inside a struct.
unittest
{
    assertTranslates(
q"C
struct Struct
{
    enum Qux
    {
        FOO,
        BAR,
        BAZ,
    };
};
C",
q"D
extern (C):

struct Struct
{
    enum Qux
    {
        FOO = 0,
        BAR = 1,
        BAZ = 2
    }
}
D");

}
