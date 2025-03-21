/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Record;

import std.algorithm.mutation;

import clang.c.Index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Context;
import dstep.translator.Enum;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.Type;
import dstep.translator.Util;

string translateRecordTypeKeyword(in Cursor cursor)
{
    if (cursor.kind == CXCursorKind.unionDecl)
        return "union";
    else
        return "struct";
}

void translatePackedAttribute(Output output, Context context, Cursor cursor)
{
    if (auto attribute = cursor.findChild(CXCursorKind.packedAttr))
        output.singleLine("align (1):");
}

struct BitField
{
    string type;
    string field;
    uint width;
}

BitField[] translateBitFields(
    Context context,
    Cursor[] cursors)
{
    static void pad(ref BitField[] bitFields, uint totalWidth)
    {
        uint padding = 0;

        for (uint size = 8; size <= 64; size *= 2)
        {
            if (totalWidth <= size)
            {
                padding = size - totalWidth;
                break;
            }
        }

        if (padding != 0)
            bitFields ~= BitField("uint", "", padding);
    }

    BitField[] bitFields;
    uint totalWidth = 0;

    foreach (cursor; cursors)
    {
        auto width = cursor.bitFieldWidth();

        if (width == 0)
        {
            pad(bitFields, totalWidth);
            totalWidth = 0;
        }
        else
        {
            bitFields ~= BitField(
                translateType(context, cursor).makeString(),
                cursor.spelling(),
                width);

            totalWidth += width;
        }
    }

    pad(bitFields, totalWidth);

    return bitFields;
}

void translateBitFields(
    Output output,
    Context context,
    Cursor[] cursors)
{
    import std.range;

    auto bitFields = translateBitFields(context, cursors);

    if (bitFields.length == 1)
    {
        auto bitField = bitFields.front;

        output.singleLine(
            `mixin(bitfields!(%s, "%s", %s));`,
            bitField.type,
            bitField.field,
            bitField.width);
    }
    else
    {
        output.multiLine("mixin(bitfields!(") in {
            foreach (index, bitField; enumerate(bitFields))
            {
                output.singleLine(
                    `%s, "%s", %s%s`,
                    bitField.type,
                    bitField.field,
                    bitField.width,
                    index + 1 == bitFields.length ? "));" : ",");
            }
        };
    }
}

void translateRecordDef(
    Output output,
    Context context,
    Cursor cursor,
    bool keepUnnamed = false)
{
    import std.algorithm;
    import std.array;
    import std.format;

    context.markAsDefined(cursor);

    auto canonical = cursor.canonical;

    auto spelling = keepUnnamed ? "" : context.translateTagSpelling(cursor);
    /* Spaghetti warning: Since unnamed values might in at least clang 19.1
     * contain "unnamed enum" or something as the name instead of being empty,
     * explicitly set it our variable to the empty string.
     *
     * Preferably, this would be disentagled and it would be ensured that there
     * is only one source of the spelling in this whole function.
     */
    spelling = spelling.isUnnamed ? "" : " " ~ spelling;
    auto type = translateRecordTypeKeyword(cursor);

    output.subscopeStrong(cursor.extent, "%s%s", type, spelling) in {
        alias predicate = (a, b) =>
            a == b ||
            a.isBitField() &&
            b.isBitField();

        auto declarations = cursor.children
            .filter!(cursor => cursor.isDeclaration)();

        if (declarations.any!(cursor => cursor.isBitField()))
            output.singleLine("import std.bitmanip : bitfields;");

        translatePackedAttribute(output, context, cursor);

        foreach (chunk; declarations.chunkBy!predicate())
        {
            auto cursor = chunk.front;

            if (cursor.isBitField)
            {
                version (D1)
                    { /* do nothing */ }
                else
                    translateBitFields(output, context, chunk.array);
            }
            else
            {
                switch (cursor.kind)
                {
                    case CXCursorKind.fieldDecl:
                        output.flushLocation(cursor);

                        auto undecorated =
                            cursor.type.kind == CXTypeKind.elaborated ?
                                cursor.type.named.undecorated :
                                cursor.type.undecorated;

                        auto declaration = undecorated.declaration;

                        if (undecorated.declaration.isValid &&
                            !context.alreadyDefined(declaration) &&
                            !declaration.isGlobalLexically)
                        {
                            context.translator.translate(output, declaration);
                        }

                        translateVariable(output, context, cursor);

                        break;

                    case CXCursorKind.unionDecl:
                    case CXCursorKind.structDecl:
                        if (cursor.type.isAnonymous || cursor.spelling.isUnnamed)
                            translateAnonymousRecord(output, context, cursor);

                        break;

                    case CXCursorKind.enumDecl:
                        translateEnum(output, context, cursor);
                        break;

                    default: break;
                }
            }
        }
    };
}

void translateRecordDecl(Output output, Context context, Cursor cursor)
{
    context.markAsDefined(cursor);

    auto spelling = context.translateTagSpelling(cursor);
    //spelling = spelling == "" ? spelling : " " ~ spelling;
    spelling = spelling.isUnnamed ? "" : " " ~ spelling;
    auto type = translateRecordTypeKeyword(cursor);
    output.singleLine(cursor.extent, "%s%s;", type, spelling);
}

void translateAnonymousRecord(Output output, Context context, Cursor cursor)
{
    if (!variablesInParentScope(cursor))
        translateRecordDef(output, context, cursor, true);
}

bool shouldSkipRecord(Context context, Cursor cursor)
{
    if (cursor.kind == CXCursorKind.structDecl ||
        cursor.kind == CXCursorKind.unionDecl)
    {
        auto typedefp = context.typedefParent(cursor.canonical);
        auto spelling = typedefp.isValid && isUnnamed(cursor.spelling)
            ? typedefp.spelling
            : cursor.spelling;

        return context.options.skipSymbols.contains(spelling);
    }

    return false;
}

bool shouldSkipRecordDefinition(Context context, Cursor cursor)
{
    if (cursor.kind == CXCursorKind.structDecl ||
        cursor.kind == CXCursorKind.unionDecl)
    {
        auto typedefp = context.typedefParent(cursor.canonical);
        auto spelling = typedefp.isValid && cursor.spelling.isUnnamed
            ? typedefp.spelling
            : cursor.spelling;

        return context.options.skipDefinitions.contains(spelling);
    }

    return false;
}

void translateRecord(Output output, Context context, Cursor record)
{
    if (context.alreadyDefined(record.canonical))
        return;

    bool skipdef = shouldSkipRecordDefinition(context, record);

    if (record.isDefinition && !skipdef)
        translateRecordDef(output, context, record);
    else if (!context.isInsideTypedef(record) && (record.definition.isEmpty || skipdef))
        translateRecordDecl(output, context, record);
}
