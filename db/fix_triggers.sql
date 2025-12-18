-- db/fix_triggers.sql
-- Este script elimina el trigger y la función previos (si existen)
-- y crea una versión más segura que atrapa errores para evitar que fallos
-- en el trigger provoquen un 500 al registrar usuarios.

BEGIN;

-- Eliminar trigger y función viejas si existen
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE t.tgname = 'handle_auth_user_insert_trigger'
  ) THEN
    EXECUTE 'DROP TRIGGER handle_auth_user_insert_trigger ON auth.users';
  END IF;
EXCEPTION WHEN others THEN
  RAISE NOTICE 'No se pudo eliminar trigger (puede que no exista o no haya permisos): %', SQLERRM;
END;
$$;

DROP FUNCTION IF EXISTS public.handle_auth_user_insert() CASCADE;

-- Crear una función segura que no propague errores
CREATE OR REPLACE FUNCTION public.handle_auth_user_insert()
RETURNS trigger AS $$
BEGIN
  BEGIN
    -- Intentamos insertar un perfil si no existe
    INSERT INTO public.usuario (id, correo, nombre, created_at)
    VALUES (
      NEW.id,
      COALESCE(NEW.email, ''),
      (CASE
        WHEN NEW.raw_user_meta_data IS NOT NULL AND (NEW.raw_user_meta_data->>'full_name') IS NOT NULL
          THEN NEW.raw_user_meta_data->>'full_name'
        ELSE COALESCE(NEW.user_metadata->>'full_name', '')
      END),
      now()
    ) ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN others THEN
    -- No propagamos el error al proceso de auth; sólo registramos un aviso.
    RAISE NOTICE 'handle_auth_user_insert suppressed error: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Intentamos crear el trigger; si falla (por permisos o ausencia de schema auth) solo mostramos NOTICE
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth') THEN
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE t.tgname = 'handle_auth_user_insert_trigger'
      ) THEN
        EXECUTE 'CREATE TRIGGER handle_auth_user_insert_trigger AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_insert()';
      END IF;
    EXCEPTION WHEN others THEN
      RAISE NOTICE 'No se pudo crear trigger en auth.users (posible falta de permisos): %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'Schema auth no existe en esta base de datos; no se crea trigger.';
  END IF;
END;
$$;

COMMIT;

-- Fin de fix_triggers.sql
