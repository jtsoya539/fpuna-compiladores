CREATE OR REPLACE PACKAGE jsonc IS

  -- Author  : Javier Meza
  -- Created : 9/9/2019 15:41:05
  -- Purpose : JSON Simplified to XML Compiler
  -- -----------------------------------------------------------------------------------
  -- Created for academic purposes in the "Compiladores y Lenguajes de Bajo Nivel" class
  -- at Facultad Politécnica, Universidad Nacional de Asunción.
  -- Description of DFA driving the Scanning process found here:
  -- https://github.com/jtsoya539/fpuna-compiladores/blob/master/Tarea1/dfa.png
  -- https://github.com/jtsoya539/fpuna-compiladores/blob/master/Tarea1/dfa_number.png

  -- Public type declarations
  TYPE t_token IS RECORD(
    token_type    VARCHAR2(30),
    string_value  VARCHAR2(32767),
    numeric_value NUMBER);

  TYPE t_reserved_words IS TABLE OF VARCHAR2(30) INDEX BY VARCHAR2(40);

  -- Public constant declarations
  -- Token types
  -- Special symbols
  tk_lsquare_brackets CONSTANT VARCHAR2(30) := 'LSQUARE_BRACKETS';
  tk_rsquare_brackets CONSTANT VARCHAR2(30) := 'RSQUARE_BRACKETS';
  tk_lcurly_brackets  CONSTANT VARCHAR2(30) := 'LCURLY_BRACKETS';
  tk_rcurly_brackets  CONSTANT VARCHAR2(30) := 'RCURLY_BRACKETS';
  tk_comma            CONSTANT VARCHAR2(30) := 'COMMA';
  tk_colon            CONSTANT VARCHAR2(30) := 'COLON';
  -- Reserved words
  tk_true  CONSTANT VARCHAR2(30) := 'TRUE';
  tk_false CONSTANT VARCHAR2(30) := 'FALSE';
  tk_null  CONSTANT VARCHAR2(30) := 'NULL';
  -- Multicharacter tokens
  tk_string CONSTANT VARCHAR2(30) := 'STRING';
  tk_number CONSTANT VARCHAR2(30) := 'NUMBER';
  -- Book-keeping tokens
  tk_id    CONSTANT VARCHAR2(30) := 'ID';
  tk_eof   CONSTANT VARCHAR2(30) := 'EOF';
  tk_error CONSTANT VARCHAR2(30) := 'ERROR';

  -- DFA states
  st_start CONSTANT PLS_INTEGER := 1;
  st_done  CONSTANT PLS_INTEGER := 2;
  -- Identifier states
  st_in_id CONSTANT PLS_INTEGER := 3;
  -- String states
  st_enter_string CONSTANT PLS_INTEGER := 4;
  st_in_string    CONSTANT PLS_INTEGER := 5;
  st_exit_string  CONSTANT PLS_INTEGER := 6;
  -- Number states
  st_in_int           CONSTANT PLS_INTEGER := 7;
  st_enter_dec        CONSTANT PLS_INTEGER := 8;
  st_enter_exp        CONSTANT PLS_INTEGER := 9;
  st_enter_signed_exp CONSTANT PLS_INTEGER := 10;
  st_in_dec           CONSTANT PLS_INTEGER := 11;
  st_in_exp           CONSTANT PLS_INTEGER := 12;

  -- ASCII characters
  cr    CONSTANT VARCHAR2(1) := chr(13);
  lf    CONSTANT VARCHAR2(1) := chr(10);
  blank CONSTANT VARCHAR2(1) := chr(32);
  tab   CONSTANT VARCHAR2(1) := chr(9);
  eot   CONSTANT VARCHAR2(1) := chr(4);

  -- Public variable declarations
  reserved_words   t_reserved_words;
  source_program   CLOB;
  target_program   CLOB;
  current_position INTEGER := 0;

  -- Public function and procedure declarations
  FUNCTION get_token RETURN t_token;
  PROCEDURE scan(i_source_program IN CLOB,
                 o_target_program OUT CLOB);

END jsonc;
/
CREATE OR REPLACE PACKAGE BODY jsonc IS

  -- Function and procedure implementations
  FUNCTION is_digit(i_char IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN TRIM(i_char) IS NOT NULL AND TRIM(translate(i_char,
                                                       '0123456789',
                                                       ' ')) IS NULL;
  END;

  FUNCTION is_alpha(i_char IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN TRIM(i_char) IS NOT NULL AND TRIM(translate(i_char,
                                                       'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
                                                       ' ')) IS NULL;
  END;

  PROCEDURE initialize_reserved_words_table IS
  BEGIN
    reserved_words('true') := jsonc.tk_true;
    reserved_words('TRUE') := jsonc.tk_true;
    reserved_words('false') := jsonc.tk_false;
    reserved_words('FALSE') := jsonc.tk_false;
    reserved_words('null') := jsonc.tk_null;
    reserved_words('NULL') := jsonc.tk_null;
  END;

  FUNCTION reserved_word_lookup(string_value IN VARCHAR2) RETURN VARCHAR2 IS
    token_type VARCHAR2(30) := jsonc.tk_error; -- Since JSON Simplified doesn't recognize identifiers
    i          VARCHAR2(40);
  BEGIN
    i := jsonc.reserved_words.first;
    WHILE i IS NOT NULL LOOP
      IF i = string_value THEN
        token_type := jsonc.reserved_words(i);
        EXIT;
      END IF;
      i := jsonc.reserved_words.next(i);
    END LOOP;
    RETURN token_type;
  END;

  PROCEDURE unget_char IS
  BEGIN
    IF jsonc.current_position > 0 THEN
      jsonc.current_position := jsonc.current_position - 1;
    END IF;
  END;

  FUNCTION get_char RETURN VARCHAR2 IS
    v_char   VARCHAR2(1);
    v_amount INTEGER := 1;
    v_length INTEGER;
  BEGIN
    IF jsonc.source_program IS NOT NULL THEN
      IF dbms_lob.isopen(jsonc.source_program) <> 1 THEN
        dbms_lob.open(jsonc.source_program, dbms_lob.lob_readonly);
      END IF;
      v_length := dbms_lob.getlength(jsonc.source_program);
    
      IF v_length > 0 AND v_length > jsonc.current_position THEN
        jsonc.current_position := jsonc.current_position + 1;
        dbms_lob.read(jsonc.source_program,
                      v_amount,
                      jsonc.current_position,
                      v_char);
      ELSE
        IF v_length = jsonc.current_position THEN
          jsonc.current_position := jsonc.current_position + 1;
        END IF;
        v_char := jsonc.eot;
      END IF;
    END IF;
  
    RETURN v_char;
  END;

  FUNCTION get_token RETURN t_token IS
    current_token t_token;
    state         PLS_INTEGER := jsonc.st_start;
    v_char        VARCHAR2(1);
    save_char     BOOLEAN;
  BEGIN
    WHILE state <> jsonc.st_done LOOP
      v_char    := jsonc.get_char;
      save_char := TRUE;
    
      CASE state
        WHEN jsonc.st_start THEN
          IF is_digit(v_char) THEN
            state := jsonc.st_in_int;
          ELSIF is_alpha(v_char) THEN
            state := jsonc.st_in_id;
          ELSIF v_char = '"' THEN
            state := jsonc.st_enter_string;
          ELSIF v_char IN (jsonc.cr, jsonc.lf, jsonc.blank, jsonc.tab) THEN
            save_char := FALSE;
            --
            dbms_lob.append(jsonc.target_program, v_char);
            --
          ELSE
            state := jsonc.st_done;
            CASE v_char
              WHEN jsonc.eot THEN
                current_token.token_type := jsonc.tk_eof;
                save_char                := FALSE;
              WHEN '{' THEN
                current_token.token_type := jsonc.tk_lcurly_brackets;
              WHEN '}' THEN
                current_token.token_type := jsonc.tk_rcurly_brackets;
              WHEN '[' THEN
                current_token.token_type := jsonc.tk_lsquare_brackets;
              WHEN ']' THEN
                current_token.token_type := jsonc.tk_rsquare_brackets;
              WHEN ',' THEN
                current_token.token_type := jsonc.tk_comma;
              WHEN ':' THEN
                current_token.token_type := jsonc.tk_colon;
              ELSE
                current_token.token_type := jsonc.tk_error;
            END CASE;
          END IF;
        
      -- ======== Identifier states ========
        WHEN jsonc.st_in_id THEN
          IF NOT is_alpha(v_char) THEN
            state                    := jsonc.st_done;
            current_token.token_type := jsonc.tk_id;
            jsonc.unget_char;
            save_char := FALSE;
          END IF;
        
      -- ======== Number states ========
        WHEN jsonc.st_in_int THEN
          IF NOT is_digit(v_char) THEN
            IF v_char = '.' THEN
              state := jsonc.st_enter_dec;
            ELSIF v_char IN ('E', 'e') THEN
              state := jsonc.st_enter_exp;
            ELSE
              state                    := jsonc.st_done;
              current_token.token_type := jsonc.tk_number;
              jsonc.unget_char;
              save_char := FALSE;
            END IF;
          END IF;
        
        WHEN jsonc.st_enter_dec THEN
          IF is_digit(v_char) THEN
            state := jsonc.st_in_dec;
          ELSE
            state                    := jsonc.st_done;
            current_token.token_type := jsonc.tk_error;
            jsonc.unget_char;
            save_char := FALSE;
          END IF;
        
        WHEN jsonc.st_enter_exp THEN
          IF is_digit(v_char) THEN
            state := jsonc.st_in_exp;
          ELSIF v_char IN ('+', '-') THEN
            state := jsonc.st_enter_signed_exp;
          ELSE
            state                    := jsonc.st_done;
            current_token.token_type := jsonc.tk_error;
            jsonc.unget_char;
            save_char := FALSE;
          END IF;
        
        WHEN jsonc.st_enter_signed_exp THEN
          IF is_digit(v_char) THEN
            state := jsonc.st_in_exp;
          ELSE
            state                    := jsonc.st_done;
            current_token.token_type := jsonc.tk_error;
            jsonc.unget_char;
            save_char := FALSE;
          END IF;
        
        WHEN jsonc.st_in_dec THEN
          IF NOT is_digit(v_char) THEN
            IF v_char IN ('E', 'e') THEN
              state := jsonc.st_enter_exp;
            ELSE
              state                    := jsonc.st_done;
              current_token.token_type := jsonc.tk_number;
              jsonc.unget_char;
              save_char := FALSE;
            END IF;
          END IF;
        
        WHEN jsonc.st_in_exp THEN
          IF NOT is_digit(v_char) THEN
            state                    := jsonc.st_done;
            current_token.token_type := jsonc.tk_number;
            jsonc.unget_char;
            save_char := FALSE;
          END IF;
        
      -- ======== String states ========
        WHEN jsonc.st_enter_string THEN
          IF v_char = '"' THEN
            state := jsonc.st_exit_string;
          ELSE
            state := jsonc.st_in_string;
          END IF;
        
        WHEN jsonc.st_in_string THEN
          IF v_char = '"' THEN
            state := jsonc.st_exit_string;
          END IF;
        
        WHEN jsonc.st_exit_string THEN
          state                    := jsonc.st_done;
          current_token.token_type := jsonc.tk_string;
          jsonc.unget_char;
          save_char := FALSE;
        
        ELSE
          state                    := jsonc.st_done;
          current_token.token_type := jsonc.tk_error;
        
      END CASE;
    
      IF save_char THEN
        current_token.string_value := current_token.string_value || v_char;
      END IF;
    
      IF state = jsonc.st_done THEN
        IF current_token.token_type = jsonc.tk_id THEN
          current_token.token_type := reserved_word_lookup(current_token.string_value);
        ELSIF current_token.token_type = jsonc.tk_number THEN
          -- current_token.numeric_value := to_number(current_token.string_value);
          NULL;
        END IF;
      END IF;
    
    END LOOP;
    RETURN current_token;
  END;

  PROCEDURE scan(i_source_program IN CLOB,
                 o_target_program OUT CLOB) IS
    token jsonc.t_token;
  BEGIN
    dbms_lob.createtemporary(jsonc.target_program, FALSE);
    dbms_lob.open(jsonc.target_program, dbms_lob.lob_readwrite);
    jsonc.source_program   := i_source_program;
    jsonc.current_position := 0;
  
    LOOP
      token := jsonc.get_token;
      dbms_lob.append(jsonc.target_program,
                      token.token_type || jsonc.blank);
      EXIT WHEN token.token_type = jsonc.tk_eof;
    END LOOP;
    o_target_program := jsonc.target_program;
  END;

BEGIN
  -- Initialization
  initialize_reserved_words_table;
END jsonc;
/
