CREATE OR REPLACE FUNCTION catbench.register_system_config(cpu_info jsonb, os_info jsonb)
RETURNS uuid
LANGUAGE plpgsql AS
$$
DECLARE
    _system_config_id uuid;
BEGIN
    SELECT id
    INTO _system_config_id
    FROM catbench.system_configs
    WHERE catbench.system_configs.cpu_info = register_system_config.cpu_info
      AND catbench.system_configs.os_info = register_system_config.os_info;
    IF NOT FOUND THEN
        INSERT INTO catbench.system_configs
            (cpu_info, os_info)
        VALUES
            (cpu_info, os_info)
        RETURNING id INTO STRICT _system_config_id;
    END IF;
    RETURN _system_config_id;
END
$$;
