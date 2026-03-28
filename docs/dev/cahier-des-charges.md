# Cahier Des Charges (Public Repo)

## Objectif

Le depot public contient uniquement le code produit, la documentation produit,
les scripts de build/test et la CI necessaires a la livraison de `kdx`.

## Regle De Confidentialite Process

- Tout processus interne d'orchestration IA/agents/workers reste interne entreprise.
- Aucun artefact d'execution interne ne doit etre versionne dans ce depot public.
- Aucun secret, token, credential, fichier de session ou journal interne ne doit etre commite.

## Exclusions Obligatoires

- Dossier interne d'automatisation: `.autodev/`
- Fichiers de pilotage interne: `AGENT_TEAMS.md`, `SCRUM_AGENTS.md`, `week_sprint.log`
- Secrets et credentials: `token.txt`, `.env*`, clefs privees

## Definition Of Done (Governance)

- Les exclusions ci-dessus sont dans `.gitignore`.
- Les revues PR refusent toute fuite de process interne ou de secret.
- Les livrables publics restent focalises sur produit, qualite et release.
