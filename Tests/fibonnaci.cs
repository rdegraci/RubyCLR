public class Fibonnaci {
  public static decimal Calc(long n) {
    decimal x1 = 1, x2 = 2, tmp;
    for (long i = 1; i < n; ++i) {
      x1 += x2;
      tmp = x2; x2 = x1; x1 = tmp;
    }
    return x1;
  }

  public static void SayHello() {
    System.Windows.Forms.MessageBox.Show("Hello, World!");
  }
}
