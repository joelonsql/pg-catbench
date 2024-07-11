CREATE OR REPLACE FUNCTION catbench.register_host(cpu_info jsonb, os_info jsonb)
RETURNS uuid
LANGUAGE plpgsql AS
$$
DECLARE
    _host_id uuid;
BEGIN
    SELECT id
    INTO _host_id
    FROM catbench.hosts
    WHERE catbench.hosts.cpu_info = register_host.cpu_info
      AND catbench.hosts.os_info = register_host.os_info;
    IF NOT FOUND THEN
        INSERT INTO catbench.hosts
            (cpu_info, os_info)
        VALUES
            (cpu_info, os_info)
        RETURNING id INTO STRICT _host_id;
    END IF;
    RETURN _host_id;
END
$$;
