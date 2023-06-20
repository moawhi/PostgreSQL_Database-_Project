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
    
    1.0 as multiplier
   
FROM 
    Moves
JOIN
    Learnable_Moves on Learnable_Moves.Learns = Moves.id 
JOIN
    Games on Learnable_Moves.Learnt_In = Games.id
JOIN
    POKEMON ON POKEMON.id = Learnable_Moves.Learnt_By

WHERE 
    Games.name = 'Sun'
    AND
    Pokemon.name = 'Goodra'
    AND
    MOVEs.Category != 'Status'
    AND
    MOVEs.Power > 0;



SELECT 
        attack_damage_results.id,
        CASE
            WHEN pokemon.first_type = Type_Effectiveness.Defending
                THEN  attack_damage_results.multiplier * Type_Effectiveness.multiplier

            WHEN pokemon.second_type = Type_Effectiveness.Defending
                THEN attack_damage_results.multiplier * Type_Effectiveness.multiplier
            WHEN pokemon.second_type = Type_Effectiveness.Defending AND pokemon.first_type = Type_Effectiveness.Defending
                THEN attack_damage_results.multiplier * Type_Effectiveness.multiplier
            ELSE 1.0
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
        pokemon.name = 'Gliscor';