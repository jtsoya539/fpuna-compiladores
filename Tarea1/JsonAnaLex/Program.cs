using System;
using System.IO;

namespace JsonAnaLex
{
    class Program
    {
        static void Main(string[] args)
        {
            string pathEntrada, pathSalida;
            if (args.Length > 1)
            {
                pathEntrada = args[0];
                pathSalida = args[1];

                try
                {
                    using (StreamReader sr = new StreamReader(pathEntrada))
                    {
                        using (StreamWriter sw = new StreamWriter(pathSalida))
                        {
                            JsonAnaLex anaLex = new JsonAnaLex(sr, sw);

                            Token token = anaLex.siguienteToken();

                            while (token.Tipo != TipoToken.EOF)
                            {
                                token = anaLex.siguienteToken();
                            }
                        }
                    }
                }
                catch (System.Exception)
                {
                    Console.WriteLine("Archivo no encontrado");
                }
            }
            else
            {
                Console.WriteLine("Debe pasar como parámetros:");
                Console.WriteLine("* Path al archivo fuente");
                Console.WriteLine("* Path al archivo de salida");
            }
        }


    }
}
