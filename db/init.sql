-- db/init.sql
-- Script para crear las tablas mínimas que usa la aplicación
-- Tablas: public.usuario, public.multimedia
-- Incluye trigger para insertar un perfil cuando se crea un usuario en auth.users (Supabase)

BEGIN;

-- Tabla de usuarios (perfil público)
CREATE TABLE IF NOT EXISTS public.usuario (
  id uuid PRIMARY KEY,
  nombre text,
  correo text,
  fecha_nacimiento date,
  telefono text,
  roll text DEFAULT 'user',
  created_at timestamptz DEFAULT now()
);

-- Tabla de multimedia (imágenes, urls)
CREATE TABLE IF NOT EXISTS public.multimedia (
  id bigserial PRIMARY KEY,
  url text NOT NULL,
  usuarioid uuid REFERENCES public.usuario(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

-- Índices recomendados
CREATE INDEX IF NOT EXISTS idx_multimedia_usuarioid ON public.multimedia(usuarioid);
CREATE INDEX IF NOT EXISTS idx_usuario_roll ON public.usuario(roll);

-- Función para crear automáticamente un perfil en public.usuario
-- cuando se inserta un nuevo usuario en auth.users (uso típico en Supabase)
-- Nota: requiere permisos para crear triggers en el schema auth.
CREATE OR REPLACE FUNCTION public.handle_auth_user_insert()
RETURNS trigger AS $$
BEGIN
  -- Inserta solo si no existe un perfil para ese id
  INSERT INTO public.usuario (id, correo, nombre, created_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    -- intenta obtener nombre desde user_metadata si existe
    (CASE
      WHEN NEW.raw_user_meta_data IS NOT NULL AND (NEW.raw_user_meta_data->>'full_name') IS NOT NULL
        THEN NEW.raw_user_meta_data->>'full_name'
      ELSE COALESCE(NEW.user_metadata->>'full_name', '')
    END),
    now()
  ) ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear trigger en auth.users para ejecutar la función luego de INSERT
-- En algunos entornos Supabase esto ya existe; si falla al crear el trigger, ignora el error.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE t.tgname = 'handle_auth_user_insert_trigger'
  ) THEN
    CREATE TRIGGER handle_auth_user_insert_trigger
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_insert();
  END IF;
EXCEPTION WHEN others THEN
  -- Si no existe el schema auth o no hay permisos, lo ignoramos y el proyecto seguirá funcionando
  RAISE NOTICE 'No se pudo crear trigger en auth.users (puede que no exista o falten permisos): %', SQLERRM;
END;
$$;

COMMIT;

-- Ejemplo de inserción manual (descomentar para probar localmente)
-- INSERT INTO public.usuario (id, nombre, correo, roll) VALUES ('00000000-0000-0000-0000-000000000000', 'Admin', 'admin@example.com', 'admin');

-- Fin de init.sql
