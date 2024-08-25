// Hello World! - Test Program
namespace HelloWorld
{
    class Hello {
        static void Main(string[] args)
        {
            System.Console.Write("Hello ");

            // Read the input
            string input = System.Console.ReadLine();

            // Only write if input is not empty
            if (!string.IsNullOrEmpty(input)) 
            {
                System.Console.WriteLine(input); 
            }
        }
    }
}