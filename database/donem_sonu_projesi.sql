PGDMP         !                |         
   donem_sonu    14.15    14.15 5    <           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            =           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            >           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            ?           1262    16574 
   donem_sonu    DATABASE     U   CREATE DATABASE donem_sonu WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'C';
    DROP DATABASE donem_sonu;
                postgres    false            �            1255    16677    cost_calculate()    FUNCTION     &  CREATE FUNCTION public.cost_calculate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_type_id int;
    v_price numeric(10,2);
    v_session_time int;
BEGIN
    -- 0 ile 10 arasında rastgele bir tam sayı üret
    -- floor(random()*(upper_bound - lower_bound + 1) + lower_bound) formülü kullanılır.
    v_session_time := floor(random() * 11)::int; -- 0'dan 10'a kadar

    -- Yeni eklenen kaydın plakasından type_id elde et
    SELECT type_id INTO v_type_id
    FROM vehicles
    WHERE plate_number = NEW.plate_number;

    -- type_id ile aracın fiyatını elde et
    SELECT price INTO v_price
    FROM vehicle_type
    WHERE type_id = v_type_id;

    -- total_cost hesapla
    NEW.session_time := v_session_time;
    NEW.cost := v_price * v_session_time;

    RETURN NEW;
END;
$$;
 '   DROP FUNCTION public.cost_calculate();
       public          postgres    false            �            1255    16649    end_day_ops() 	   PROCEDURE     N  CREATE PROCEDURE public.end_day_ops()
    LANGUAGE plpgsql
    AS $$
DECLARE
    last_id BIGINT;
BEGIN
    -- Vehicles tablosunu sıfırla
    TRUNCATE vehicles;

    -- parking_records tablosundaki en son record_id değerini bul
    SELECT COALESCE(MAX(record_id), 0) INTO last_id FROM parking_records;

    -- Sequence değerini güncelle (ertesi güne yeni id ile başlamak için)
    PERFORM setval('parking_records_record_id_seq', last_id + 1, false);

    -- system_info tablosunda last_end_day_id güncelle
    UPDATE system_info SET last_end_day_id = last_id WHERE id = 1;
END;
$$;
 %   DROP PROCEDURE public.end_day_ops();
       public          postgres    false            �            1255    16634    reuse_user_id()    FUNCTION     =  CREATE FUNCTION public.reuse_user_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_id INT;
BEGIN
    -- Boşta kalan en küçük user_id değerini bul
    SELECT MIN(a.user_id + 1) INTO new_id
    FROM users a
    WHERE NOT EXISTS (
        SELECT 1
        FROM users b
        WHERE b.user_id = a.user_id + 1
    );

    -- Eğer boşta kalan bir ID varsa, onu geri dön
    IF new_id IS NOT NULL AND new_id < OLD.user_id THEN
        UPDATE users
        SET user_id = new_id
        WHERE user_id = OLD.user_id;
    END IF;

    RETURN NEW;
END;
$$;
 &   DROP FUNCTION public.reuse_user_id();
       public          postgres    false            �            1259    16614    parking_records    TABLE     �   CREATE TABLE public.parking_records (
    record_id integer NOT NULL,
    plate_number character varying(20),
    entry_time timestamp without time zone NOT NULL,
    cost numeric(10,2),
    session_time integer,
    user_id integer
);
 #   DROP TABLE public.parking_records;
       public         heap    postgres    false            �            1259    16613    parking_records_record_id_seq    SEQUENCE     �   CREATE SEQUENCE public.parking_records_record_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.parking_records_record_id_seq;
       public          postgres    false    217            @           0    0    parking_records_record_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.parking_records_record_id_seq OWNED BY public.parking_records.record_id;
          public          postgres    false    216            �            1259    16576    roles    TABLE     �   CREATE TABLE public.roles (
    role_id integer NOT NULL,
    role_name character varying(50) NOT NULL,
    role_description text
);
    DROP TABLE public.roles;
       public         heap    postgres    false            �            1259    16575    roles_role_id_seq    SEQUENCE     �   CREATE SEQUENCE public.roles_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.roles_role_id_seq;
       public          postgres    false    210            A           0    0    roles_role_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.roles_role_id_seq OWNED BY public.roles.role_id;
          public          postgres    false    209            �            1259    16657    system_info    TABLE     c   CREATE TABLE public.system_info (
    id integer NOT NULL,
    last_end_day_id bigint DEFAULT 0
);
    DROP TABLE public.system_info;
       public         heap    postgres    false            �            1259    16656    system_info_id_seq    SEQUENCE     �   CREATE SEQUENCE public.system_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.system_info_id_seq;
       public          postgres    false    221            B           0    0    system_info_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.system_info_id_seq OWNED BY public.system_info.id;
          public          postgres    false    220            �            1259    16645    total_earnings_view    VIEW       CREATE VIEW public.total_earnings_view AS
 SELECT sum(parking_records.cost) AS total_earnings
   FROM public.parking_records
  WHERE (parking_records.record_id > ( SELECT system_info.last_end_day_id
           FROM public.system_info
          WHERE (system_info.id = 1)));
 &   DROP VIEW public.total_earnings_view;
       public          postgres    false    217    221    221    217            �            1259    16585    users    TABLE     �   CREATE TABLE public.users (
    user_id integer NOT NULL,
    user_name character varying(50) NOT NULL,
    password character varying(100),
    role_id integer
);
    DROP TABLE public.users;
       public         heap    postgres    false            �            1259    16584    users_user_id_seq    SEQUENCE     �   CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.users_user_id_seq;
       public          postgres    false    212            C           0    0    users_user_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;
          public          postgres    false    211            �            1259    16597    vehicle_type    TABLE     �   CREATE TABLE public.vehicle_type (
    type_id integer NOT NULL,
    type_name character varying(50) NOT NULL,
    price numeric(10,2)
);
     DROP TABLE public.vehicle_type;
       public         heap    postgres    false            �            1259    16603    vehicles    TABLE     �   CREATE TABLE public.vehicles (
    plate_number character varying(20) NOT NULL,
    type_id integer,
    is_detected boolean NOT NULL
);
    DROP TABLE public.vehicles;
       public         heap    postgres    false            �            1259    16641    vehicle_income_view    VIEW     �  CREATE VIEW public.vehicle_income_view AS
 SELECT vt.type_name AS "Araç Tipi",
    count(pr.plate_number) AS "Araç Sayısı",
    sum(pr.cost) AS "Toplam Kazanç"
   FROM ((public.parking_records pr
     JOIN public.vehicles v ON (((pr.plate_number)::text = (v.plate_number)::text)))
     JOIN public.vehicle_type vt ON ((v.type_id = vt.type_id)))
  WHERE (pr.cost IS NOT NULL)
  GROUP BY vt.type_name;
 &   DROP VIEW public.vehicle_income_view;
       public          postgres    false    214    217    217    215    215    214            �            1259    16596    vehicle_type_type_id_seq    SEQUENCE     �   CREATE SEQUENCE public.vehicle_type_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.vehicle_type_type_id_seq;
       public          postgres    false    214            D           0    0    vehicle_type_type_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.vehicle_type_type_id_seq OWNED BY public.vehicle_type.type_id;
          public          postgres    false    213            �           2604    16617    parking_records record_id    DEFAULT     �   ALTER TABLE ONLY public.parking_records ALTER COLUMN record_id SET DEFAULT nextval('public.parking_records_record_id_seq'::regclass);
 H   ALTER TABLE public.parking_records ALTER COLUMN record_id DROP DEFAULT;
       public          postgres    false    216    217    217            �           2604    16579    roles role_id    DEFAULT     n   ALTER TABLE ONLY public.roles ALTER COLUMN role_id SET DEFAULT nextval('public.roles_role_id_seq'::regclass);
 <   ALTER TABLE public.roles ALTER COLUMN role_id DROP DEFAULT;
       public          postgres    false    210    209    210            �           2604    16660    system_info id    DEFAULT     p   ALTER TABLE ONLY public.system_info ALTER COLUMN id SET DEFAULT nextval('public.system_info_id_seq'::regclass);
 =   ALTER TABLE public.system_info ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    221    220    221            �           2604    16588    users user_id    DEFAULT     n   ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);
 <   ALTER TABLE public.users ALTER COLUMN user_id DROP DEFAULT;
       public          postgres    false    211    212    212            �           2604    16600    vehicle_type type_id    DEFAULT     |   ALTER TABLE ONLY public.vehicle_type ALTER COLUMN type_id SET DEFAULT nextval('public.vehicle_type_type_id_seq'::regclass);
 C   ALTER TABLE public.vehicle_type ALTER COLUMN type_id DROP DEFAULT;
       public          postgres    false    213    214    214            7          0    16614    parking_records 
   TABLE DATA           k   COPY public.parking_records (record_id, plate_number, entry_time, cost, session_time, user_id) FROM stdin;
    public          postgres    false    217   	D       0          0    16576    roles 
   TABLE DATA           E   COPY public.roles (role_id, role_name, role_description) FROM stdin;
    public          postgres    false    210   hD       9          0    16657    system_info 
   TABLE DATA           :   COPY public.system_info (id, last_end_day_id) FROM stdin;
    public          postgres    false    221   �D       2          0    16585    users 
   TABLE DATA           F   COPY public.users (user_id, user_name, password, role_id) FROM stdin;
    public          postgres    false    212   E       4          0    16597    vehicle_type 
   TABLE DATA           A   COPY public.vehicle_type (type_id, type_name, price) FROM stdin;
    public          postgres    false    214   xE       5          0    16603    vehicles 
   TABLE DATA           F   COPY public.vehicles (plate_number, type_id, is_detected) FROM stdin;
    public          postgres    false    215   �E       E           0    0    parking_records_record_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.parking_records_record_id_seq', 85, true);
          public          postgres    false    216            F           0    0    roles_role_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.roles_role_id_seq', 3, true);
          public          postgres    false    209            G           0    0    system_info_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.system_info_id_seq', 1, true);
          public          postgres    false    220            H           0    0    users_user_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.users_user_id_seq', 21, true);
          public          postgres    false    211            I           0    0    vehicle_type_type_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.vehicle_type_type_id_seq', 5, true);
          public          postgres    false    213            �           2606    16619 $   parking_records parking_records_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.parking_records
    ADD CONSTRAINT parking_records_pkey PRIMARY KEY (record_id);
 N   ALTER TABLE ONLY public.parking_records DROP CONSTRAINT parking_records_pkey;
       public            postgres    false    217            �           2606    16583    roles roles_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_id);
 :   ALTER TABLE ONLY public.roles DROP CONSTRAINT roles_pkey;
       public            postgres    false    210            �           2606    16663    system_info system_info_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.system_info
    ADD CONSTRAINT system_info_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.system_info DROP CONSTRAINT system_info_pkey;
       public            postgres    false    221            �           2606    16633    users unique_user_name 
   CONSTRAINT     V   ALTER TABLE ONLY public.users
    ADD CONSTRAINT unique_user_name UNIQUE (user_name);
 @   ALTER TABLE ONLY public.users DROP CONSTRAINT unique_user_name;
       public            postgres    false    212            �           2606    16590    users users_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public            postgres    false    212            �           2606    16602    vehicle_type vehicle_type_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY public.vehicle_type
    ADD CONSTRAINT vehicle_type_pkey PRIMARY KEY (type_id);
 H   ALTER TABLE ONLY public.vehicle_type DROP CONSTRAINT vehicle_type_pkey;
       public            postgres    false    214            �           2606    16607    vehicles vehicles_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (plate_number);
 @   ALTER TABLE ONLY public.vehicles DROP CONSTRAINT vehicles_pkey;
       public            postgres    false    215            �           2620    16678 ,   parking_records parking_records_cost_trigger    TRIGGER     �   CREATE TRIGGER parking_records_cost_trigger BEFORE INSERT ON public.parking_records FOR EACH ROW EXECUTE FUNCTION public.cost_calculate();
 E   DROP TRIGGER parking_records_cost_trigger ON public.parking_records;
       public          postgres    false    227    217            �           2620    16635    users reuse_id_trigger    TRIGGER     s   CREATE TRIGGER reuse_id_trigger AFTER DELETE ON public.users FOR EACH ROW EXECUTE FUNCTION public.reuse_user_id();
 /   DROP TRIGGER reuse_id_trigger ON public.users;
       public          postgres    false    212    222            �           2606    16672 *   parking_records fk_parking_records_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.parking_records
    ADD CONSTRAINT fk_parking_records_user_id FOREIGN KEY (user_id) REFERENCES public.users(user_id);
 T   ALTER TABLE ONLY public.parking_records DROP CONSTRAINT fk_parking_records_user_id;
       public          postgres    false    217    3476    212            �           2606    16689    users users_role_id_fkey    FK CONSTRAINT     |   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(role_id);
 B   ALTER TABLE ONLY public.users DROP CONSTRAINT users_role_id_fkey;
       public          postgres    false    3472    212    210            �           2606    16679    vehicles vehicles_type_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.vehicle_type(type_id);
 H   ALTER TABLE ONLY public.vehicles DROP CONSTRAINT vehicles_type_id_fkey;
       public          postgres    false    3478    215    214            7   O   x�e˻�0E�ڞ"����B�A���J�V�=����Ԣú목�>d��"��*�������SҢ��zA���?ϫ3      0   �   x�5�K
B1��q�����c.@�(Μ�6�`�B�"������w�pHE*���\�~C�;y���}�"��faG����L�)5�6ǲ���qN�c����q��ndW���+�JΘ�9����:��B� �:�      9      x�3�4������ �]      2   K   x�3�LL��̃��FƜ�\Ɯ�ũE`$`�eʙ������ a#.�����	2�22�h�44����� <��      4   P   x��A� ���aHr7@�`PI*������$�D�L�QM���;����?0�.��G���2OēN����1�      5   :   x�K�4�L�JLLI3���S��9M�<C#��bC#cNc(�(U�gV���� 7.�     