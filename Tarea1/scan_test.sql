DECLARE
  source_program CLOB;
  target_program CLOB;
BEGIN
  source_program := '{  
   "personas":[  
      {  
         "ci":1234567,
         "nombre":"Julio Perez",
         "casado":false,
         "hijos":[  

         ]
      },
      {  
         "ci":7654321,
         "nombre":"Juan Gomez",
         "casado":true,
         "hijos":[  
            {  
               "nombre":"Jorge",
               "edad":18
            },
            {  
               "nombre":"Valeria",
               "edad":16
            }
         ]
      }
   ]
}';
  jsonc.scan(i_source_program => source_program,
             o_target_program => target_program);
  dbms_output.put_line(target_program);
END;
