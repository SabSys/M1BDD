-- Table des produits
CREATE TABLE produits (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(255) NOT NULL,
    stock INT NOT NULL CHECK (stock >= 0)
);

-- Table des commandes
CREATE TABLE commandes (
    id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    date_commande TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des produits commandés
CREATE TABLE produits_commandes (
    id SERIAL PRIMARY KEY,
    commande_id INT NOT NULL REFERENCES commandes(id) ON DELETE CASCADE,
    produit_id INT NOT NULL REFERENCES produits(id) ON DELETE CASCADE,
    quantite INT NOT NULL CHECK (quantite > 0)
);
-- Ajouter des produits
INSERT INTO produits (nom, stock) VALUES
('Produit A', 50),
('Produit B', 30),
('Produit C', 20);
DO $$
BEGIN
    CREATE OR REPLACE FUNCTION passer_commande(
        client_id INT,
        produits JSONB -- Format attendu : [{"produit_id": 1, "quantite": 2}, ...]
    ) RETURNS VOID AS $$
    DECLARE
        produit RECORD;
        commande_id INT;
    BEGIN
        -- Démarrer une transaction
        BEGIN
            -- Créer une nouvelle commande
            INSERT INTO commandes (client_id) VALUES (client_id) RETURNING id INTO commande_id;

            -- Traiter chaque produit de la commande
            FOR produit IN SELECT * FROM jsonb_array_elements(produits) LOOP
                -- Verrouiller la ligne du produit
                SELECT stock
                FROM produits
                WHERE id = (produit->>'produit_id')::INT
                FOR UPDATE;

                -- Vérifier la disponibilité en stock
                IF (SELECT stock
                    FROM produits
                    WHERE id = (produit->>'produit_id')::INT) < (produit->>'quantite')::INT THEN
                    RAISE EXCEPTION 'Produit % insuffisant en stock.', (produit->>'produit_id')::INT;
                END IF;

                -- Ajouter le produit à la commande
                INSERT INTO produits_commandes (commande_id, produit_id, quantite)
                VALUES (
                    commande_id,
                    (produit->>'produit_id')::INT,
                    (produit->>'quantite')::INT
                );

                -- Mettre à jour le stock
                UPDATE produits
                SET stock = stock - (produit->>'quantite')::INT
                WHERE id = (produit->>'produit_id')::INT;
            END LOOP;
        EXCEPTION WHEN OTHERS THEN
            -- Annuler la transaction en cas d'erreur
            ROLLBACK;
            RAISE;
        END;

        -- Confirmer la transaction
        COMMIT;
    END;
    $$ LANGUAGE plpgsql;
END;
$$;
BEGIN;

SELECT stock
FROM produits
WHERE id = 1
FOR UPDATE;

-- Effectue la mise à jour
UPDATE produits
SET stock = stock - 5
WHERE id = 1;

COMMIT;


--LOCK TABLE produits IN SHARE ROW EXCLUSIVE MODE;
