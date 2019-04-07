using System;
using System.IO;

namespace JsonAnaLex
{
    class JsonAnaLex
    {
        private StreamReader reader;
        private StreamWriter writer;
        public int NumeroLinea { get; set; }

        public JsonAnaLex(StreamReader streamReader, StreamWriter streamWriter)
        {
            reader = streamReader;
            writer = streamWriter;
            NumeroLinea = 1;
        }

        public void errorLexico(string mensaje)
        {
            Console.WriteLine($"Linea {NumeroLinea}: Error lexico. {mensaje}");
        }

        public Token siguienteToken()
        {
            Token token = new Token();
            bool avanzar = false;
            int caracter = reader.Read();

            char[] palabra = new char[30];
            int i = 0;

            while (caracter > -1)
            {
                if (System.Char.Equals((char)caracter, ' ') || System.Char.Equals((char)caracter, '\t'))
                {
                    writer.Write((char)caracter);
                    avanzar = true;
                }
                else if (System.Char.Equals((char)caracter, '\n'))
                {
                    writer.Write((char)caracter);
                    NumeroLinea++;
                    avanzar = true;
                }
                else if (System.Char.Equals((char)caracter, '['))
                {
                    token.Tipo = TipoToken.L_CORCHETE;
                    token.ValorTexto = ((char)caracter).ToString();
                    break;
                }
                else if (System.Char.Equals((char)caracter, ']'))
                {
                    token.Tipo = TipoToken.R_CORCHETE;
                    token.ValorTexto = ((char)caracter).ToString();
                    break;
                }
                else if (System.Char.Equals((char)caracter, '{'))
                {
                    token.Tipo = TipoToken.L_LLAVE;
                    token.ValorTexto = ((char)caracter).ToString();
                    break;
                }
                else if (System.Char.Equals((char)caracter, '}'))
                {
                    token.Tipo = TipoToken.R_LLAVE;
                    token.ValorTexto = ((char)caracter).ToString();
                    break;
                }
                else if (System.Char.Equals((char)caracter, ','))
                {
                    token.Tipo = TipoToken.COMA;
                    token.ValorTexto = ((char)caracter).ToString();
                    break;
                }
                else if (System.Char.Equals((char)caracter, ':'))
                {
                    token.Tipo = TipoToken.DOS_PUNTOS;
                    token.ValorTexto = ((char)caracter).ToString();
                    break;
                }
                else if (System.Char.Equals((char)caracter, '"'))
                {
                    i = 0;
                    palabra[i] = (char)caracter;
                    i++;

                    while (!System.Char.Equals((char)reader.Peek(), '"'))
                    {
                        caracter = reader.Read();
                        palabra[i] = (char)caracter;
                        i++;
                    }

                    if (System.Char.Equals((char)reader.Peek(), '"'))
                    {
                        caracter = reader.Read();
                        palabra[i] = (char)caracter;
                        i++;

                        string literalCadena = new string(palabra, 0, i);
                        token.Tipo = TipoToken.LITERAL_CADENA;
                        token.ValorTexto = literalCadena;
                        break;
                    }
                }
                else if (System.Char.IsLetter((char)caracter))
                {
                    i = 0;
                    palabra[i] = (char)caracter;
                    i++;

                    while (System.Char.IsLetter((char)reader.Peek()))
                    {
                        caracter = reader.Read();
                        palabra[i] = (char)caracter;
                        i++;
                    }

                    string palabraClave = new string(palabra, 0, i);
                    if (String.Equals(palabraClave, "true") || String.Equals(palabraClave, "TRUE"))
                    {
                        token.Tipo = TipoToken.PR_TRUE;
                        token.ValorTexto = palabraClave;
                        break;
                    }
                    else if (String.Equals(palabraClave, "false") || String.Equals(palabraClave, "FALSE"))
                    {
                        token.Tipo = TipoToken.PR_FALSE;
                        token.ValorTexto = palabraClave;
                        break;
                    }
                    else if (String.Equals(palabraClave, "null") || String.Equals(palabraClave, "NULL"))
                    {
                        token.Tipo = TipoToken.PR_FALSE;
                        token.ValorTexto = palabraClave;
                        break;
                    }
                    else
                    {
                        errorLexico($"{palabraClave} no esperado");
                        avanzar = true;
                    }
                }
                else if (System.Char.IsDigit((char)caracter))
                {
                    i = 0;
                    palabra[i] = (char)caracter;
                    i++;

                    while (System.Char.IsDigit((char)reader.Peek()))
                    {
                        caracter = reader.Read();
                        palabra[i] = (char)caracter;
                        i++;
                    }

                    string literalNum = new string(palabra, 0, i);
                    token.Tipo = TipoToken.LITERAL_NUM;
                    token.ValorTexto = literalNum;
                    break;
                }
                else if (caracter > -1)
                {
                    errorLexico($"{((char)caracter).ToString()} no esperado");
                    avanzar = true;
                }

                if (avanzar)
                {
                    caracter = reader.Read();
                    avanzar = false;
                }
            }

            if (caracter == -1)
            {
                token.Tipo = TipoToken.EOF;
                token.ValorTexto = "EOF";
            }

            writer.Write($"{token.Tipo} ");
            Console.WriteLine($"Linea {NumeroLinea}: {token.ValorTexto} => {token.Tipo}");

            return token;
        }

    }
}