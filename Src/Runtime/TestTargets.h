#pragma once

namespace RubyClr {
  namespace Tests {
    public ref class GenericMethodTests {
    public:
      generic <typename T>
      static T Min(T lhs, T rhs) {
        return lhs < rhs ? lhs : rhs;
      }

      generic <typename T>
      static T Min(T a, T b, T c) {
        T lowest = a;
        if (b < lowest) lowest = b;
        if (c < lowest) lowest = c;
        return lowest;
      }

      // This method will expand ambiguously at runtime if we use an Int16 expansion of the above method
      generic <typename T>
      static T Min(T a, T b, short c) {
        T lowest = a;
        if (b < lowest) lowest = b;
        if (c < (int)lowest) lowest = (T)c;
        return (T)42;
      }
    };
  }
}