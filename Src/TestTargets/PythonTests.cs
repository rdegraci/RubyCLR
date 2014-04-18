/* **********************************************************************************
 *
 * Copyright (c) Microsoft Corporation. All rights reserved.
 *
 * This source code is subject to terms and conditions of the Shared Source License
 * for IronPython. A copy of the license can be found in the License.html file
 * at the root of this distribution. If you can not locate the Shared Source License
 * for IronPython, please send an email to ironpy@microsoft.com.
 * By using this source code in any fashion, you are agreeing to be bound by
 * the terms of the Shared Source License for IronPython.
 *
 * You must not remove this notice, or any other, from this software.
 *
 * **********************************************************************************/

using System;
using System.Text;
using System.Collections.Generic;
using System.Collections;

namespace RubyClr.Tests {
  public class BindingTestClass {
    public static object Bind(bool parm) {
      return parm;
    }

    public static object Bind(string parm) {
      return parm;
    }

    public static object Bind(int parm) {
      return parm;
    }
  }

  public class InheritedBindingBase {
    public virtual object Bind(bool parm) {
      return "Base bool";
    }

    public virtual object Bind(string parm) {
      return "Base string";
    }

    public virtual object Bind(int parm) {
      return "Base int";
    }
  }

  public class InheritedBindingSub : InheritedBindingBase {
    public override object Bind(bool parm) {
      return "Subclass bool";
    }
    public override object Bind(string parm) {
      return "Subclass string";
    }
    public override object Bind(int parm) {
      return "Subclass int";
    }
  }

  [Flags]
  public enum BindResult {
    None = 0,

    Bool = 1,
    Byte = 2,
    Char = 3,
    Decimal = 4,
    Double = 5,
    Float = 6,
    Int = 7,
    Long = 8,
    Object = 9,
    SByte = 10,
    Short = 11,
    String = 12,
    UInt = 13,
    ULong = 14,
    UShort = 15,

    Array = 0x1000,
    Out = 0x2000,
    Ref = 0x4000,
  }

  public class BindTest {
    public static object BoolValue = (bool)true;
    public static object ByteValue = (byte)0;
    public static object CharValue = (char)'\0';
    public static object DecimalValue = (decimal)0;
    public static object DoubleValue = (double)0;
    public static object FloatValue = (float)0;
    public static object IntValue = (int)0;
    public static object LongValue = (long)0;
    public static object ObjectValue = (object)new System.Collections.Hashtable();
    public static object SByteValue = (sbyte)0;
    public static object ShortValue = (short)0;
    public static object StringValue = (string)String.Empty;
    public static object UIntValue = (uint)0;
    public static object ULongValue = (ulong)0;
    public static object UShortValue = (ushort)0;

    public static BindResult Bind() { return BindResult.None; }

    public static BindResult Bind(bool value) { return BindResult.Bool; }
    public static BindResult Bind(byte value) { return BindResult.Byte; }
    public static BindResult Bind(char value) { return BindResult.Char; }
    public static BindResult Bind(decimal value) { return BindResult.Decimal; }
    public static BindResult Bind(double value) { return BindResult.Double; }
    public static BindResult Bind(float value) { return BindResult.Float; }
    public static BindResult Bind(int value) { return BindResult.Int; }
    public static BindResult Bind(long value) { return BindResult.Long; }
    public static BindResult Bind(object value) { return BindResult.Object; }
    public static BindResult Bind(sbyte value) { return BindResult.SByte; }
    public static BindResult Bind(short value) { return BindResult.Short; }
    public static BindResult Bind(string value) { return BindResult.String; }
    public static BindResult Bind(uint value) { return BindResult.UInt; }
    public static BindResult Bind(ulong value) { return BindResult.ULong; }
    public static BindResult Bind(ushort value) { return BindResult.UShort; }

    public static BindResult Bind(bool[] value) { return BindResult.Bool | BindResult.Array; }
    public static BindResult Bind(byte[] value) { return BindResult.Byte | BindResult.Array; }
    public static BindResult Bind(char[] value) { return BindResult.Char | BindResult.Array; }
    public static BindResult Bind(decimal[] value) { return BindResult.Decimal | BindResult.Array; }
    public static BindResult Bind(double[] value) { return BindResult.Double | BindResult.Array; }
    public static BindResult Bind(float[] value) { return BindResult.Float | BindResult.Array; }
    public static BindResult Bind(int[] value) { return BindResult.Int | BindResult.Array; }
    public static BindResult Bind(long[] value) { return BindResult.Long | BindResult.Array; }
    public static BindResult Bind(object[] value) { return BindResult.Object | BindResult.Array; }
    public static BindResult Bind(sbyte[] value) { return BindResult.SByte | BindResult.Array; }
    public static BindResult Bind(short[] value) { return BindResult.Short | BindResult.Array; }
    public static BindResult Bind(string[] value) { return BindResult.String | BindResult.Array; }
    public static BindResult Bind(uint[] value) { return BindResult.UInt | BindResult.Array; }
    public static BindResult Bind(ulong[] value) { return BindResult.ULong | BindResult.Array; }
    public static BindResult Bind(ushort[] value) { return BindResult.UShort | BindResult.Array; }

    public static BindResult Bind(out bool value) { value = false; return BindResult.Bool | BindResult.Out; }
    public static BindResult Bind(out byte value) { value = 0; return BindResult.Byte | BindResult.Out; }
    public static BindResult Bind(out char value) { value = '\0'; return BindResult.Char | BindResult.Out; }
    public static BindResult Bind(out decimal value) { value = 0; return BindResult.Decimal | BindResult.Out; }
    public static BindResult Bind(out double value) { value = 0; return BindResult.Double | BindResult.Out; }
    public static BindResult Bind(out float value) { value = 0; return BindResult.Float | BindResult.Out; }
    public static BindResult Bind(out int value) { value = 0; return BindResult.Int | BindResult.Out; }
    public static BindResult Bind(out long value) { value = 0; return BindResult.Long | BindResult.Out; }
    public static BindResult Bind(out object value) { value = null; return BindResult.Object | BindResult.Out; }
    public static BindResult Bind(out sbyte value) { value = 0; return BindResult.SByte | BindResult.Out; }
    public static BindResult Bind(out short value) { value = 0; return BindResult.Short | BindResult.Out; }
    public static BindResult Bind(out string value) { value = null; return BindResult.String | BindResult.Out; }
    public static BindResult Bind(out uint value) { value = 0; return BindResult.UInt | BindResult.Out; }
    public static BindResult Bind(out ulong value) { value = 0; return BindResult.ULong | BindResult.Out; }
    public static BindResult Bind(out ushort value) { value = 0; return BindResult.UShort | BindResult.Out; }

    public static BindResult BindRef(ref bool value) { value = false; return BindResult.Bool | BindResult.Ref; }
    public static BindResult BindRef(ref byte value) { value = 0; return BindResult.Byte | BindResult.Ref; }
    public static BindResult BindRef(ref char value) { value = '\0'; return BindResult.Char | BindResult.Ref; }
    public static BindResult BindRef(ref decimal value) { value = 0; return BindResult.Decimal | BindResult.Ref; }
    public static BindResult BindRef(ref double value) { value = 0; return BindResult.Double | BindResult.Ref; }
    public static BindResult BindRef(ref float value) { value = 0; return BindResult.Float | BindResult.Ref; }
    public static BindResult BindRef(ref int value) { value = 0; return BindResult.Int | BindResult.Ref; }
    public static BindResult BindRef(ref long value) { value = 0; return BindResult.Long | BindResult.Ref; }
    public static BindResult BindRef(ref object value) { value = null; return BindResult.Object | BindResult.Ref; }
    public static BindResult BindRef(ref sbyte value) { value = 0; return BindResult.SByte | BindResult.Ref; }
    public static BindResult BindRef(ref short value) { value = 0; return BindResult.Short | BindResult.Ref; }
    public static BindResult BindRef(ref string value) { value = null; return BindResult.String | BindResult.Ref; }
    public static BindResult BindRef(ref uint value) { value = 0; return BindResult.UInt | BindResult.Ref; }
    public static BindResult BindRef(ref ulong value) { value = 0; return BindResult.ULong | BindResult.Ref; }
    public static BindResult BindRef(ref ushort value) { value = 0; return BindResult.UShort | BindResult.Ref; }
  }

  namespace DispatchHelpers {
    public class B { }
    public class D : B { }

    public interface I { }
    public class C1 : I { }
    public class C2 : I { }

    public enum Color { Red, Blue }
  }

  public class Dispatch {
    public static int Flag = 0;

    public void M1(int arg) { Flag = 101; }
    public void M1(DispatchHelpers.Color arg) { Flag = 201; }

    public void M2(int arg) { Flag = 102; }
    public void M2(int arg, params int[] arg2) { Flag = 202; }

    public void M3(int arg) { Flag = 103; }
    public void M3(int arg, int arg2) { Flag = 203; }

    public void M4(int arg) { Flag = 104; }
    public void M4(int arg, __arglist) { Flag = 204; }

    public void M5(float arg) { Flag = 105; }
    public void M5(double arg) { Flag = 205; }

    public void M6(char arg) { Flag = 106; }
    public void M6(string arg) { Flag = 206; }

    public void M7(int arg) { Flag = 107; }
    public void M7(params int[] args) { Flag = 207; }

    public void M8(int arg) { Flag = 108; }
    public void M8(ref int arg) { Flag = 208; arg = 999; }

    public void M10(ref int arg) { Flag = 210; arg = 999; }

    public void M11(int arg, int arg2) { Flag = 111; }
    public void M11(DispatchHelpers.Color arg, int arg2) { Flag = 211; }

    public void M12(int arg, DispatchHelpers.Color arg2) { Flag = 112; }
    public void M12(DispatchHelpers.Color arg, int arg2) { Flag = 212; }

    public void M20(DispatchHelpers.B arg) { Flag = 120; }

    public void M22(DispatchHelpers.B arg) { Flag = 122; }
    public void M22(DispatchHelpers.D arg) { Flag = 222; }

    public void M23(DispatchHelpers.I arg) { Flag = 123; }
    public void M23(DispatchHelpers.C2 arg) { Flag = 223; }

    public void M50(params DispatchHelpers.B[] args) { Flag = 150; }

    public void M51(params DispatchHelpers.B[] args) { Flag = 151; }
    public void M51(params DispatchHelpers.D[] args) { Flag = 251; }

    public void M60(int? arg) { Flag = 160; }

    public void M70(Dispatch arg) { Flag = 170; }
    public static void M71(Dispatch arg) { Flag = 171; }

    public static void M81(Dispatch arg, int arg2) { Flag = 181; }
    public void M81(int arg) { Flag = 281; }

    public static void M82(bool arg) { Flag = 182; }
    public static void M82(string arg) { Flag = 282; }

    public void M83(bool arg) { Flag = 183; }
    public void M83(string arg) { Flag = 283; }

    public void M90<T>(int arg) { Flag = 190; }

    public void M91(int arg) { Flag = 191; }
    public void M91<T>(int arg) { Flag = 291; }
  }

  public class DispatchBase {
    public virtual void M1(int arg) { Dispatch.Flag = 101; }
    public virtual void M2(int arg) { Dispatch.Flag = 102; }
    public virtual void M3(int arg) { Dispatch.Flag = 103; }
    public void M4(int arg) { Dispatch.Flag = 104; }
    public virtual void M5(int arg) { Dispatch.Flag = 105; }
    public virtual void M6(int arg) { Dispatch.Flag = 106; }
  }

  public class DispatchDerived : DispatchBase {
    public override void M1(int arg) { Dispatch.Flag = 201; }
    public virtual void M2(DispatchHelpers.Color arg) { Dispatch.Flag = 202; }
    public virtual void M3(string arg) { Dispatch.Flag = 203; }
    public void M4(string arg) { Dispatch.Flag = 204; }
    public new virtual void M5(int arg) { Dispatch.Flag = 205; }
  }

  public class ConversionDispatch {
    public object Array(object[] arr) {
      return arr;
    }

    public object IntArray(int[] arr) {
      return arr;
    }

    public object StringArray(string[] arr) {
      return arr;
    }

    public object Enumerator(IEnumerator<object> enm) {
      return enm;
    }

    public object StringEnumerator(IEnumerator<string> enm) {
      return enm;
    }

    public object IntEnumerator(IEnumerator<int> enm) {
      return enm;
    }

    public object ArrayList(System.Collections.ArrayList list) {
      return list;
    }
    public object ObjIList(IList<object> list) {
      return list;
    }

    public object IntIList(IList<int> list) {
      return list;
    }

    public object StringIList(IList<string> list) {
      return list;
    }

    public object ObjList(List<object> list) {
      return list;
    }

    public object IntList(List<int> list) {
      return list;
    }

    public object StringList(List<string> list) {
      return list;
    }

    public object DictTest(IDictionary<object, object> dict) {
      return dict;
    }

    public object IntDictTest(IDictionary<int, int> dict) {
      return dict;
    }

    public object StringDictTest(IDictionary<string, string> dict) {
      return dict;
    }

    public object MixedDictTest(IDictionary<string, int> dict) {
      return dict;
    }

    public object HashtableTest(Hashtable dict) {
      return dict;
    }
  }

  public class FieldTest {
    public IList<Type> Field;
  }
}