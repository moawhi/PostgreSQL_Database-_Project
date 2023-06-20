-- COMP3311 23T1 Ass2 ... SQL helper Views/Functions
-- Add any views or functions you need into this file
-- Note: it must load without error into a freshly created Movies database
-- Note: you must submit this file even if you add nothing to it

-- The `dbpop()` function is provided for you in the dump file
-- This is provided in case you accidentally delete it

DROP TYPE IF EXISTS Population_Record CASCADE;
CREATE TYPE Population_Record AS (
	Tablename Text,
	Ntuples   Integer
);

CREATE OR REPLACE FUNCTION DBpop() RETURNS SETOF Population_Record
AS $$
DECLARE
    rec Record;
    qry Text;
    res Population_Record;
    num Integer;
BEGIN
    FOR rec IN SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename LOOP
        qry := 'SELECT count(*) FROM ' || quote_ident(rec.tablename);

        execute qry INTO num;

        res.tablename := rec.tablename;
        res.ntuples   := num;

        RETURN NEXT res;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

--
-- Example Views/Functions
-- These Views/Functions may or may not be useful to you.
-- You may modify or delete them as you see fit.
--

-- `Move_Learning_Info`
-- The `Learnable_Moves` table is a relation between Pokemon, Moves, Games and Requirements.
-- As it just consists of foreign keys, it is not very easy to read.
-- This view makes it easier to read by displaying the names of the Pokemon, Moves and Games instead of their IDs.
CREATE OR REPLACE VIEW Move_Learning_Info(Pokemon, Move, Game, Requirement) AS
SELECT
    P.Name,
    M.Name,
    G.Name,
    R.Assertion
FROM
    Learnable_Moves AS L
    JOIN
    Pokemon         AS P ON Learnt_By   = P.ID
    JOIN
    Games           AS G ON Learnt_In   = G.ID
    JOIN
    Moves           AS M ON Learns      = M.ID
    JOIN
    Requirements    AS R ON Learnt_When = R.ID
;

-- `Super_Effective`
-- This function takes a type name and
-- returns a set of all types that it is super effective against (multiplier > 100)
-- eg Water is super effective against Fire, so `Super_Effective('Water')` will return `Fire` (amongst others)
CREATE OR REPLACE FUNCTION Super_Effective(_Type Text) RETURNS SETOF Text
AS $$
SELECT
    B.Name
FROM
    Types              AS A
    JOIN
    Type_Effectiveness AS E ON A.ID = E.Attacking
    JOIN
    Types              AS B ON B.ID = E.Defending
WHERE
    A.Name = _Type
    AND
    E.Multiplier > 100
$$ LANGUAGE SQL;

--
-- Your Views/Functions Below Here
-- Remember This file must load into a clean Pokemon database in one pass without any error
-- NOTICEs are fine, but ERRORs are not
-- Views/Functions must be defined in the correct order (dependencies first)
-- eg if my_supper_clever_function() depends on my_other_function() then my_other_function() must be defined first
-- Your Views/Functions Below Here
--

--
-- Q1 HELPER QUERY

CREATE OR REPLACE VIEW Game_Info(Game) AS
SELECT 
    games.name 
FROM 
    games 
ORDER BY random() LIMIT 10;

CREATE OR REPLACE FUNCTION Game_Info_check(_Game Text) RETURNS SETOF Text 
AS $$
SELECT 
    games.name 
FROM 
    games
WHERE
    games.name = _Game
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Location_Info_check(_Location Text) RETURNS SETOF Text 
AS $$
SELECT 
    locations.name 
FROM 
    locations
WHERE
    locations.name = _Location
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Location_InGame_check(_Game Text, _Location Text) RETURNS SETOF Text 
AS $$
SELECT 
    locations.name 
FROM 
    locations
JOIN
    games on locations.APPEARS_IN = games.id
WHERE
    locations.name = _Location
    AND 
    games.name = _Game
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Pokemon_InGame_check(_Game Text, _Pokemon Text) RETURNS SETOF Text
AS $$
SELECT 
    pokemon.name
FROM
    games
    join 
    Pokedex on pokedex.game = games.id 
    join 
    Pokemon on pokedex.national_id = pokemon.id
WHERE 
    games.name = _Game
    AND
    pokemon.name = _Pokemon
$$ LANGUAGE SQL;


DROP TYPE IF EXISTS PokemonData cascade;
CREATE TYPE PokemonData as (pokemonName text, species text, pokemonFirstType text, pokemonSecondType text, pokedexNumber Integer, regional_id Integer, pokemonId Integer);

CREATE OR REPLACE FUNCTION Pokemon_Game_Info(_Type Text) RETURNS SETOF PokemonData
AS $$
SELECT 
    pokemon.name, pokemon.species , pokemon.first_type, pokemon.second_type, (pokemon.id::Pokemon_ID).Pokedex_Number, pokedex.regional_id, (pokemon.id::Pokemon_ID).Variation_Number
FROM 
    games
    join 
    Pokedex on pokedex.game = games.id 
    join 
    Pokemon on pokedex.national_id = pokemon.id
WHERE 
    games.name = _Type
ORDER BY random() LIMIT 10
$$ LANGUAGE SQL;


CREATE OR REPLACE FUNCTION Pokemon_ID_func(_Type Text) RETURNS SETOF Pokemon_ID
AS $$
SELECT 
    pokemon.id
FROM 
    Pokemon 
WHERE 
    pokemon.name = _Type
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Types_Info(_Type Integer) RETURNS SETOF Text
AS $$
SELECT 
    Types.name
FROM 
    Types
WHERE 
    Types.id = _Type
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Pokemon_Abilities_Info(_Input Pokemon_ID) RETURNS SETOF Text
AS $$
SELECT 
    abilities.name
FROM 
    abilities
    JOIN
    knowable_abilities ON knowable_abilities.knows = abilities.id
    JOIN
    pokemon ON pokemon.id = knowable_abilities.known_by
WHERE 
    pokemon.id = _Input
ORDER BY abilities.id
$$ LANGUAGE SQL;


DROP TYPE IF EXISTS MoveData cascade;
CREATE TYPE MoveData as (MoveName text, of_Type text, Category text, Power text, Accuracy text, MovesId Integer);

CREATE OR REPLACE FUNCTION Pokemon_Moves_Info(_Type Text, _Type2 Text) RETURNS SETOF MoveData
AS $$
SELECT DISTINCT
    Moves.name, Types.name, Moves.Category, Moves.Power, Moves.Accuracy, Moves.id
FROM 
    Moves
    JOIN
    Learnable_Moves ON Learnable_Moves.Learns = Moves.id
    JOIN
    Pokemon ON Pokemon.id = Learnable_Moves.Learnt_By
    JOIN
    Games on Learnable_Moves.Learnt_In = Games.ID
    JOIN
    Types on Moves.of_Type = Types.id
WHERE 
    Pokemon.name = _Type
    AND
    Games.Name = _Type2
    AND
    Learnable_Moves.Learnt_When < 101
    AND
    Learnable_Moves.Learnt_When > 0
ORDER BY Moves.id
$$ LANGUAGE SQL;

-- Q2 HELPER QUERY

DROP TYPE IF EXISTS PreEvoData cascade;
CREATE TYPE PreEvoData as (evolutionsId text, PokemoName text, RequirementsAssertion text, evolutionRequirementsInverted boolean);

CREATE OR REPLACE FUNCTION Pokemon_pre(_Type Pokemon_ID) RETURNS SETOF PreEvoData
AS $$
SELECT 
    evolutions.id, Pokemon.name, Requirements.Assertion, evolution_requirements.inverted
FROM 
    evolutions 
JOIN
    evolution_requirements on evolution_requirements.evolution = evolutions.id
JOIN
    Requirements on Requirements.id= evolution_requirements.Requirement
JOIN 
    Pokemon ON Pokemon.ID = evolutions.pre_evolution
WHERE 
    evolutions.post_evolution = _Type
ORDER BY 
    evolutions.id, Evolution_Requirements.Inverted, Requirements.id
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Pokemon_post(_Type Pokemon_ID) RETURNS SETOF PreEvoData
AS $$
SELECT 
    evolutions.id, Pokemon.name, Requirements.Assertion, evolution_requirements.inverted
FROM 
    evolutions 
JOIN
    evolution_requirements on evolution_requirements.evolution = evolutions.id
JOIN
    Requirements on Requirements.id= evolution_requirements.Requirement
JOIN 
    Pokemon ON Pokemon.ID = evolutions.post_evolution
WHERE 
    evolutions.pre_evolution = _Type
ORDER BY 
    evolutions.id, Evolution_Requirements.Inverted, Requirements.id
$$ LANGUAGE SQL;

-- Q3 HELPER QUERY

DROP TYPE IF EXISTS DensityData cascade;
CREATE TYPE DensityData as (Locations text, total_density real, game_count int, average_density real);

CREATE OR REPLACE FUNCTION Pokemon_density(_Region Regions) RETURNS SETOF DensityData
AS $$
SELECT 
    Locations.name as location, 
    SUM(ROUND((6*POWER(10, -5)*ENCOUNTERS.RARITY * POKEMON.AVERAGE_WEIGHT / (pi() * power(POKEMON.AVERAGE_HEIGHT,3) ))::numeric, 4)) as total_density,
    count(DISTINCT games.id) as game_count,
    ROUND((SUM(ROUND((6*POWER(10, -5)*ENCOUNTERS.RARITY * POKEMON.AVERAGE_WEIGHT / (pi() * power(POKEMON.AVERAGE_HEIGHT,3) ))::numeric, 7)) / count(DISTINCT games.id))::numeric, 4) as average_density
FROM 
    GAMES 
JOIN 
    LOCATIONS ON LOCATIONS.APPEARS_IN = GAMES.ID 
RIGHT JOIN 
    ENCOUNTERS ON ENCOUNTERS.OCCURS_AT = LOCATIONS.ID
JOIN 
    POKEMON ON POKEMON.ID = ENCOUNTERS.OCCURS_WITH 
WHERE
    GAMES.region = _Region
GROUP BY
    Location
ORDER BY 
    average_density DESC, location;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Pokemon_No_density(_Region Regions) RETURNS SETOF Text
AS $$
SELECT 
    Locations.name as location
FROM 
    LOCATIONS
JOIN
    GAMES ON LOCATIONS.APPEARS_IN = GAMES.ID 
LEFT OUTER JOIN 
    ENCOUNTERS ON ENCOUNTERS.OCCURS_AT = LOCATIONS.ID 
WHERE
    GAMES.region = _Region
    AND
    ENCOUNTERS.OCCURS_AT is NULL
GROUP BY
    location
ORDER BY 
    location;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION is_valid_region(name text) 
RETURNS boolean 
AS $$
BEGIN
    RETURN name IN ('Kanto', 'Johto', 'Hoenn', 'Sinnoh', 'Unova', 'Kalos', 'Alola', 'Galar', 'Hisui', 'Paldea');
END;
$$ LANGUAGE plpgsql;

DROP TYPE IF EXISTS EncounterData cascade;
CREATE TYPE EncounterData as (ENCOUNTERid int, PokemonId Pokemon_ID, PokemonName Text,
    ENCOUNTERSRARITY probability, EGG_GROUP Text, 
    abilities Text, min int, max int,  
    RequirementsAssertion Text, 
    ENCOUNTERREQUIREMENTSinverted Text);


-- Q4 HELPER QUERY

CREATE OR REPLACE FUNCTION Pokemon_Encounters(_Location Text, _Game Text) RETURNS SETOF EncounterData
AS $$
SELECT DISTINCT 
    ENCOUNTERS.id,
    Pokemon.Id, 
    Pokemon.name,
    ENCOUNTERS.RARITY, 
    STRING_AGG(DISTINCT EGG_GROUPS.name, ', ') as EGG_GROUP, 
    STRING_AGG(DISTINCT abilities.name, ', ') as abilities, 
    (ENCOUNTERS.LEVELS::Closed_Range).min ,
    (ENCOUNTERS.LEVELS::Closed_Range).max,  
    STRING_AGG(DISTINCT Requirements.Assertion, E'\n\t\t\t') as encounterRequirement,
    ENCOUNTER_REQUIREMENTS.inverted
FROM 
    LOCATIONS 
JOIN
    GAMES ON LOCATIONS.APPEARS_IN = GAMES.ID 
JOIN 
    ENCOUNTERS ON ENCOUNTERS.OCCURS_AT = LOCATIONS.ID 
JOIN
    POKEMON ON POKEMON.ID = ENCOUNTERS.OCCURS_WITH
JOIN
    ENCOUNTER_REQUIREMENTS ON ENCOUNTER_REQUIREMENTS.ENCOUNTER = ENCOUNTERS.ID
JOIN
    knowable_abilities ON pokemon.id = knowable_abilities.known_by AND knowable_abilities.hidden = 'f' 
JOIN
    abilities ON knowable_abilities.knows = abilities.id 
JOIN
    Requirements ON Requirements.ID = ENCOUNTER_REQUIREMENTS.Requirement
JOIN
    IN_GROUP ON POKEMON.ID = IN_GROUP.pokemon
JOIN
    EGG_GROUPS ON IN_GROUP.EGG_GROUP = EGG_GROUPS.ID 
WHERE
    Locations.name = _Location
    AND
    GAMES.name = _Game
GROUP BY
    ENCOUNTERS.id, POKEMON.id, encounters.rarity, encounters.levels, encounter_requirements.inverted
ORDER BY 
    ENCOUNTERS.RARITY DESC, Pokemon.name, (ENCOUNTERS.LEVELS::Closed_Range).max
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION First_Types_Info_Encounter(_Type Text) RETURNS SETOF Text
AS $$
SELECT 
    Types.name
FROM 
    Types
JOIN
    POKEMON ON POKEMON.first_type = Types.id
WHERE 
    Pokemon.name = _Type
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION Second_Types_Info_Encounter(_Type Text) RETURNS SETOF Text
AS $$
SELECT 
    Types.name
FROM 
    Types
JOIN
    POKEMON ON POKEMON.second_type = Types.id
WHERE 
    Pokemon.name = _Type
$$ LANGUAGE SQL;

-- Q5 Helper Query


CREATE OR REPLACE FUNCTION Attack_Damage(_Game Text, _Type Text) RETURNS TABLE (
    id integer,
    name text,
    category Move_Categories,
    power Statistic,
    of_type int,
    attack_damage Statistic,
    defend_damage int,
    STAB numeric,
    multiplier int
    
) AS $$
BEGIN
    DROP TABLE IF EXISTS attack_damage_results;
    CREATE TABLE attack_damage_results AS
    SELECT DISTINCT
    MOves.id,
    Moves.name,
    Moves.Category,
    Moves.Power,
    Moves.of_Type,
    case
        WHEN MOVEs.Category = 'Special' THEN (POKEMON.base_stats).Special_Attack
        ELSE (POKEMON.base_stats).Attack
    end as Attack_Damage,

    0 as defend_damage,

    case
        WHEN MOVEs.of_Type = Pokemon.first_type OR MOves.of_Type = Pokemon.second_type THEN 1.5
        ELSE 1.0
    end as STAB,
    
    100 as multiplier
   
FROM 
    Moves
JOIN
    Learnable_Moves on Learnable_Moves.Learns = Moves.id 
JOIN
    Games on Learnable_Moves.Learnt_In = Games.id
JOIN
    POKEMON ON POKEMON.id = Learnable_Moves.Learnt_By

WHERE 
    Games.name = _Game
    AND
    Pokemon.name = _Type
    AND
    MOVEs.Category != 'Status'
    AND
    MOVEs.Power > 0;

    RETURN QUERY SELECT * FROM attack_damage_results;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION Update_Depending(pokemon_name TEXT)
RETURNS VOID
AS $$
BEGIN
    UPDATE attack_damage_results 
    SET 
        defend_damage = CASE 
            WHEN category = 'Special' THEN (Pokemon.base_stats).Special_Defense
            ELSE (Pokemon.base_stats).Defense
        END   
    FROM
        pokemon
    JOIN     
        Type_Effectiveness ON 
        (Type_Effectiveness.Defending = pokemon.first_type OR Type_Effectiveness.Defending = pokemon.second_type) 
    WHERE pokemon.name = pokemon_name;
END
$$ LANGUAGE PLPGSQL;


DROP TYPE IF EXISTS MultiplierData cascade;
CREATE TYPE MultiplierData as (id int, multiplier int,
        pokemon_first_type int,
        pokemon_second_type int,
        attack_damage_results_of_type int,
        Type_Effectiveness_Defending int);

CREATE OR REPLACE FUNCTION Update_multiplier(pokemon_name TEXT) 
RETURNS SETOF MultiplierData
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        attack_damage_results.id,
        CASE
            WHEN pokemon.first_type = Type_Effectiveness.Defending
                THEN  attack_damage_results.multiplier * Type_Effectiveness.multiplier / 100

            WHEN pokemon.second_type = Type_Effectiveness.Defending
                THEN attack_damage_results.multiplier * Type_Effectiveness.multiplier / 100
            ELSE 100
        END as multiplier,
        pokemon.first_type,
        pokemon.second_type,
        attack_damage_results.of_type,
        Type_Effectiveness.Defending
    FROM 
        Type_Effectiveness 
    RIGHT OUTER JOIN 
        attack_damage_results on attack_damage_results.of_type = Type_Effectiveness.attacking
    JOIN pokemon ON (Type_Effectiveness.Defending = pokemon.first_type OR Type_Effectiveness.Defending = pokemon.second_type) 
    WHERE
        pokemon.name = pokemon_name;
END;
$$ LANGUAGE PLPGSQL;
