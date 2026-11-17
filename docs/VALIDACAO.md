# Validação da entrega

Data: **17/11/2026**. Godot **4.5.1**, renderizador Compatibility. Ambiente disponível: Linux x64, Celeron N4020 de dois núcleos, Intel UHD Graphics 600 / Mesa, cerca de 10 GiB de RAM.

## Solo completo e bots

`godot --headless --path . -- --test-solo`

O teste usa o botão **JOGAR SOLO** do menu, confirma um humano e 15 bots e mantém o humano parado. Os tickets começam em 100 para cada time. Não injeta capturas, danos, mortes ou vitória. Acelera o tempo em 8× e usa 240 ticks físicos por segundo no teste, preservando o mesmo delta de 1/30 s da partida normal.

Resultado: **passou**. Em 163,7 s de tempo de partida houve quatro capturas, uma retomada de bandeira, duas disputas e 165 mortes. O time BRASA terminou com zero tickets e NÉVOA com 2; a tela de resultado foi exibida. Evidência: [test-solo.json](test-solo.json).

## Regras e infantaria/veículos

`godot --headless --path . -- --test-rules`

Cenários controlados executam as funções reais de autoridade, com personagens posicionados pelo teste. Conferem captura neutra, pausa com dois times presentes, neutralização e retomada, fallback de spawn perdido, cura, reparo, motorista, passageiro, saída, disparo antiveículo contra o jipe, destruição e custo único do ocupante morto, reaparecimento na base, conservação de munição na recarga, deitar, consumo de fôlego, restauração de postura, proteção da base, sangria, resultado, revanche e retorno ao menu. Evidência: [test-rules.json](test-rules.json).

## LAN

Cada cenário usa **três processos independentes**: host jogável e dois clientes com vagas humanas, conectados por IP `127.0.0.1`. Os 13 lugares restantes são preenchidos por bots. O cenário posiciona personagens e mantém bots afastados durante as verificações específicas; não equivale a uma partida LAN física com pessoas operando os clientes.

- Times opostos e cooperação com o host: cliente A em NÉVOA e cliente B em BRASA.
- Cooperação entre clientes: ambos em NÉVOA.

São verificados entrada por IP, escolha de time, efetivo de 16, captura por cliente e replicação, pedido remoto de renascimento, entrada no jipe, direção por comando do cliente, destruição decidida pelo host, replicação do veículo e do resultado. Os testes finais também verificam replicação de postura deitada e fôlego.

Evidências: `test-lan-opposed-{host,clientA,clientB}.json` e `test-lan-coop-{host,clientA,clientB}.json`.

No encerramento do cenário cooperativo, o ENet registrou um envio para um peer que já estava fechando (`max channels: 0`). Todos os eventos e asserts de host/clientes passaram; esse registro de encerramento continua como limitação observada.

**Não testados:** duas pessoas usando computadores separados, rede Wi-Fi física e partidas entre Windows/Linux/macOS. Não havia outras máquinas/sistemas disponíveis. Não se afirma que esses cenários foram aprovados.

## Interface e renderização

A interface foi renderizada e inspecionada em OpenGL na UHD 600. Capturas do motor, sem mockup: [menu](menu.png), [gameplay](gameplay.png), [inserção](deployment.png) e [mapa](vale-seco.png) e [soldados](equipment.png).

O executável Linux inclui um diagnóstico acionado por `-- --benchmark --bench-label=release-validation`: usa o botão Solo real, renderiza uma partida com 15 bots durante 35 s, ignora input humano e encerra. No build exportado, salva relatório e captura em `user://diagnostics/`. O executável Linux 0.2.0 foi executado com esse diagnóstico: média de 99,0 FPS, P99 de 32,3 ms e 96 draw calls médios no preset Leve; relatório em `benchmark-release-v2.json`. Isso verifica a execução do pacote exportado; não é uma avaliação presencial de todos os controles por um jogador.

## Exportações

| Alvo | Conteúdo | Validação disponível |
|---|---|---|
| Linux x64 | ELF x86-64, recursos embutidos | Exportação, abertura OpenGL e diagnóstico do executável |
| Windows x64 | PE x86-64, recursos embutidos | Exportação e inspeção de formato; sem execução no Windows |
| macOS universal | ZIP com `.app`, Mach-O x86_64 + arm64 | Exportação e inspeção do binário universal; sem execução no macOS |

A revisão 0.2.0 de 17/11 atualiza texturas, materiais, modelos e detalhes de arquitetura. Solo completo, regras e os dois cenários LAN foram executados novamente; os JSONs registram o resultado.

Todos são builds release sem assinatura comercial. Veja os hashes em `builds/SHA256SUMS.txt` e os detalhes de desempenho em [OTIMIZACAO.md](OTIMIZACAO.md).

O projeto é um protótipo militar próprio inspirado em BF2. Não foi validada equivalência visual ou funcional completa com Battlefield 2.
