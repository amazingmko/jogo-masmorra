# Otimização — pendente para a etapa 4 (depois do 1º mundo completo)

Teste no POCO X3 Pro (versão 0.4-teste, 17/10):
- Troca de andar pelo portal: resolvida (sem travar).
- Ainda trava um pouco:
  1. Quando os mobs começam a surgir (início da onda).
  2. Ao usar o Provocar da Icamiaba.

Suspeitas para investigar:
- Surgir dos mobs: vários inimigos criados no mesmo quadro (malhas, materiais, colisão, barra de vida).
  Ideias: espalhar o surgimento em vários quadros; reaproveitar inimigos (pool); pré-carregar os modelos 3D novos.
- Provocar: vários efeitos de uma vez (ícone em cada inimigo, anel no chão, texto). Ideias: menos partículas,
  ícone compartilhado, medir no celular qual parte pesa.
- Geral: limite de partículas na tela, opção de qualidade (baixa/média/alta), menos polígonos de longe,
  sombras mais baratas, medir de novo com os modelos 3D finais (mobs, chefe, harpia, armadilha, pinguela).
