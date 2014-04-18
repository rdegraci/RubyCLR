using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Drawing;

namespace RubyClr.Tests {
  public interface ICalc {
    int Add(int x, int y);
    int Subtract(int x, int y);
  }

  public struct MyPoint {
    int x_;
    int y_;

    public MyPoint(Size s) {
      x_ = s.Width;
      y_ = s.Height;
    }

    public int X {
      get { return x_; }
      set { x_ = value; }
    }

    public int Y {
      get { return y_; }
      set { y_ = value; }
    }
  }

  public class Person : IComparable {
    string name_;

    public Person(string name) {
      name_ = name;
    }

    public string Name {
      get { return name_; }
    }

    public static Person Create() {
      return new Person("John");
    }

    public static Person Create(string name) {
      return new Person(name);
    }

    public int CompareTo(object other) {
      return Name.CompareTo(((Person)other).Name);
    }
  }

  public class MarshalerHelper {
    public MarshalerHelper() {
      Name = "Hello";
    }

    public virtual int[] GetOneDimensionalArray() {
      return new int[] { 0, 1, 2, 3 };
    }

    public int[,] GetTwoDimensionalArray() {
      return new int[,] { {0, 1}, {1, 0} };
    }

    public static int[] StaticGetOneDimensionalArray() {
      return new int[] { 0, 1, 2, 3 };
    }

    public static int[,] StaticGetTwoDimensionalArray() {
      return new int[,] { {0, 1}, {1, 0} };
    }

    public static int[,,] StaticGetThreeDimensionalArray() {
      return new int[,,] { { {0, 1}, {1, 0} }, { {0, 1}, {1, 0} } };
    }

    public static decimal GetDecimal() {
      return 3.14159m;
    }

    public Person GetPerson() {
      return Person.Create();
    }

    public string Name;

    public static Point UsePoint(Point p) {
      p.X += 1;
      p.Y += 1;
      return p;
    }

    public static Point GetPoint() {
      return new Point(3, 4);
    }
  }

  public class CallbackTests {
    public string Name;
    public event EventHandler Event;

    public CallbackTests(string name) {
      Name = name;
    }

    public void CallMeBack() {
      Event(this, EventArgs.Empty);
    }
  }

  public delegate void AddResultEventHandler(object sender, int result);

  public class DelegateCalc {
    private int x_;
    private int y_;

    public event AddResultEventHandler AddResult;
    public static event AddResultEventHandler StaticAddResult;

    public DelegateCalc(int x, int y) {
      x_ = x; 
      y_ = y;
    }

    public void Add() {
      AddResult(this, x_ + y_);
    }

    public static void StaticTest() {
      StaticAddResult(null, 42);
    }
  }

  public class CoVarianceTarget {
    public int Method(string value) {
      return 1;
    }

    public string Method(int value) {
      return "1";
    }

    public static int StaticMethod(string value) {
      return 1;
    }

    public static string StaticMethod(int value) {
      return "1";
    }
  };

  public class ParentClass {
    public class NestedClass {
      public class MoreNestedClass {
        public static int Method() {
          return 100;
        }
      }
      public static int Method() {
        return 42;
      }
    }
  }

  public class PropertyOverloads {
    private int[] _values;
    private static int  _value;
    // private static int  _overloadedValue;
  
    public PropertyOverloads() {
      _values = new int[10];
    }

    public static int StaticProperty {
      get { return _value; }
      set { _value = value; }
    }

    // Can't do this from C#, so this C++ code is included here for posterity.
    // Its corresponding test has also been commented out for posterity.
   
    //static property int OverloadedProperty {
    //  int get() { return 1; }
    //}

    //static property int OverloadedProperty[int] {
    //  int get(int x) { return _overloadedValue; }
    //  void set(int x, int value) { _overloadedValue = value; }
    //}

    public int this[int index] {
      get { return _values[index]; }
      set { _values[index] = value; }
    }

    public int this[string index] {
      get { return _values[Convert.ToInt32(index)]; }
      set { _values[Convert.ToInt32(index)] = value; }
    }
  }

  public class MethodOverloads {
    public int Method(int p1, object p2) {
      return 1;
    }

    public int Method(string p1, object p2) {
      return 2;
    }

    public int Method(DataColumn p1, object p2) {
      return 3;
    }
  }

  public class DisposableClass : IDisposable {
    public static bool Disposed = false;

    public void BadMethod() {
      throw new Exception();
    }
    
    public void GoodMethod() {}

    public void Dispose() {
      Disposed = true;
    }
  }

  public class AnotherDisposableClass : IDisposable {
    public static bool Disposed = false;

    public void BadMethod() {
      throw new Exception();
    }

    public void GoodMethod() { }

    public void Dispose() {
      Disposed = true;
    }
  }

  public class GenericTestHelper {
    public static List<String> GetNames() {
      List<String> names = new List<String>();
      names.Add("John");
      names.Add("Paul");
      names.Add("George");
      names.Add("Ringo");
      return names;
    }

    public static void AddName(String name, List<String> names) {
      names.Add(name);
    }
  }

  public class DataBinderTestHelper {
    public static List<String> Bind(IList dataSource) {
      List<String> result = new List<String>();
      foreach (String name in dataSource)
        result.Add(name);

      return result;
    }

    public static void AddElementsToRubyArray(IList array) {
      array.Add(3);
      array.Add(4);
    }

    public static void ClearElements(IList array) {
      array.Clear();
    }

    public static void InsertElementsAtStartOfRubyArray(IList array) {
      array.Insert(0, 2);
      array.Insert(0, 1);
    }

    public static bool ContainsAOne(IList array) {
      return array.Contains(1);
    }

    public static int GetIndexOfFour(IList array) {
      return array.IndexOf(4);
    }

    public static void RemoveThree(IList array) {
      array.Remove(3);
    }

    public static void RemoveFirstElement(IList array) {
      array.RemoveAt(0);
    }

    public static void RemoveSecondElement(IList array) {
      array.RemoveAt(1);
    }

    public static void AddOneToEachElement(IList array) {
      for (int i = 0; i < array.Count; ++i)
        array[i] = (int)array[i] + 1;
    }
  }

  public class ArrayTestHelper {
    public static void AddOne(Int32[] elements) {
      for (int i = 0; i < elements.Length; ++i)
        elements[i] += 1;
    }
  }

  // Generics test targets
  public class Test {
    public static Type[] GetTypes() { return new Type[0]; }
  }

  public class Test<T> {
    public static Type[] GetTypes() { return new Type[] { typeof(T) }; }
  }

  public class Test<T, U> {
    public static Type[] GetTypes() { return new Type[] { typeof(T), typeof(U) }; }
  }

  public class NullablePropertyTestTargets {
    private Person _person;

    public NullablePropertyTestTargets() {
      _data = "default";
    }

    private String _data;

    public String Property {
      get { return _data; }
      set { _data = value; }
    }

    public Person Person {
      get { return _person; }
      set { _person = value; }
    }

    public IComparable GetInterface() {
      return new Person("Steve");
    }

    public IComparable GetNullInterface() {
      return null;
    }
  }

  public class DateTimeTestTargets {
    static DateTime _now;
    
    public static DateTime GetCurrentDate() {
      _now = new DateTime(1000);  //  DateTime.Now;
      return _now;
    }

    public static bool CompareWithNow(DateTime date) {
      return _now == date;
    }
  }

  public class ActiveRecordTestHelper {

  }
}