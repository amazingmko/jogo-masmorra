# Jogo de masmorra (nome provisório)

Jogo mobile de exploração de masmorras com heróis de classe e elemento, itens e runs roguelite em tempo real. Inspirado nas mecânicas de Soul Knight e da versão ARPG do Guild of Guardians — sem usar arte, personagens, nomes ou textos deles.

## Estrutura

```
.claude/skills/   skills do replica-skill (Claude Code)
.kiro/skills/     as mesmas skills (Kiro)
replica/          saídas do método, uma etapa alimenta a próxima
  recon.md              mapa de telas, fluxos, modelo de dados, escopo
  features.csv          matriz de features (must/should/could/skip)
  fixes-preliminar.md   o que os jogadores reclamam (amostra fina)
  reviews.csv           planilha para colar reviews reais
  themes-jogos.json     temas de reclamação para jogos (EN e PT)
```

## Ordem do método

recon (feito) → entrepreneur (preliminar) → architect → design → build → test → diff → brand → launch → deploy

## Ferramentas úteis

```bash
python3 .claude/skills/replica-diff/parity.py replica/features.csv
python3 .claude/skills/replica-entrepreneur/reviews.py replica/reviews.csv --themes replica/themes-jogos.json --out replica/feedback.md
```
