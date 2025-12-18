-- db/allow_insert_policy.sql
-- Crea una política de RLS que permite INSERTs en public.usuario
-- necesaria para que el trigger/servicio de Auth pueda crear el perfil
-- durante el signup. Esto es una política enfocada a resolver el error
-- "new row violates row-level security policy for table \"usuario\"".

BEGIN;

-- Habilitar RLS (si no está habilitado)
ALTER TABLE IF EXISTS public.usuario ENABLE ROW LEVEL SECURITY;

-- Política para permitir INSERTs desde el proceso de signup / triggers.
-- Esta política permite únicamente insertar filas (no concede SELECT/UPDATE/DELETE).
-- Recomendación: después de verificar el signup, revisa y endurece la política.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'usuario' AND policyname = 'allow_insert_from_auth'
  ) THEN
    CREATE POLICY allow_insert_from_auth
      ON public.usuario
      FOR INSERT
      WITH CHECK (true);
  ELSE
    RAISE NOTICE 'Policy allow_insert_from_auth already exists.';
  END IF;
END;
$$;

COMMIT;

-- Nota: Esta política solo permite INSERTs. Para operaciones posteriores (SELECT/UPDATE/DELETE)
-- deberás añadir políticas más restrictivas según tus requisitos (por ejemplo, permitir SELECT
-- y UPDATE solo al propietario o a usuarios autenticados).
