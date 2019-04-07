namespace JsonAnaLex
{
    public class Token
    {
        public TipoToken Tipo { get; set; }
        public string ValorTexto { get; set; }
        public int ValorNumero { get; set; }

        public Token()
        {
            this.Tipo = TipoToken.EOF;
            this.ValorTexto = "";
            this.ValorNumero = 0;
        }
    }
}