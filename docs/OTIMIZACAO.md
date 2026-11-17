# Desempenho e visual

Medições em 16 e 17/11/2026 no hardware disponível: **Intel Celeron N4020 (2 núcleos), Intel UHD Graphics 600, Linux/Mesa, Compatibility**. Benchmark com partida solo, 15 bots, cinco segundos de aquecimento e 30 segundos de coleta. VSync e limite de FPS desativados somente durante a medição. O jogo normal limita a 60 FPS.

| Medição | Janela | FPS médio | P99 do tempo de quadro | Draw calls médios |
|---|---|---:|---:|---:|
| Inicial, sem otimização | 1280 × 800 | 33,6 | 106,0 ms | 925 |
| Release anterior, 16/11 | 960 × 600, escala 3D 80% | 79,6 | 39,9 ms | 104 |
| Novos assets antes do atlas dos soldados, fonte, 17/11 | 960 × 600, escala 3D 80% | 74,1 | 52,3 ms | 130 |
| Release 0.2.0 final, atlas dos soldados, 17/11 | 960 × 600, escala 3D 80% | **99,0** | **32,3 ms** | **96** |

A última linha foi medida no executável Linux exportado, não no editor. Evidência: [benchmark-release-v2.json](benchmark-release-v2.json) e [captura real](benchmark-release-v2.png).

O modo Leve é o padrão. A diferença inclui mudanças de resolução e sombras; **não é uma comparação na mesma qualidade gráfica**. A média não garante mínimo de 60 FPS. Há quadros mais lentos, especialmente durante aquecimento, combate e atividade do sistema. Os resultados completos estão em `benchmark-*.json`; `static_memory_mb` é apenas a memória estática monitorada pela Godot, não o uso total do processo.

O mapa e os modelos têm primitivas consolidadas em poucas superfícies com cores por vértice, evitando centenas de objetos de desenho. A aquisição de alvos dos bots é escalonada; a navegação mantém o caminho até mudar o objetivo. A física roda a 30 Hz; os snapshots LAN continuam a 20 Hz com acumulador. Vozes e traçantes usam pools fixos. O HUD desenha até 30 vezes por segundo. O modo Leve usa sombras estáticas projetadas em vez de mapas de sombras dinâmicos.

O visual ganhou céu procedural, relevo, palmeiras, sacos de areia, barris, postes, caixa-d’água e texturas difusas de 512 × 512 de terreno, concreto, metal, tecido, asfalto e camuflagem; portas, janelas, frisos, antena, capacetes, coletes, marcha animada no shader e armas mais definidas. O objetivo é uma estética militar de 2005 com conteúdo próprio e baixo custo. Não reproduz os modelos, texturas ou a fidelidade exata de Battlefield 2, nem usa assets extraídos dele.

A revisão visual usa tiles próprios gerados com imagegen, formas chanfradas nos modelos e fachadas detalhadas. As UVs são projetadas durante a consolidação, evitando a projeção triplanar por pixel. Um atlas permite consolidar os materiais de cada soldado em uma só superfície. Proveniência, prompt e arquivos em [ASSETS.md](ASSETS.md).

Para repetir a medição, a partir da raiz com Godot 4.5.1:

```bash
godot --path . -- --benchmark --quality=0 --bench-label=meu-pc
```

Não rode outros testes simultaneamente. O comando abre uma partida, ignora input humano, mede e encerra. O JSON e a captura são salvos em `docs/`; o benchmark precisa ser executado a partir do projeto-fonte em um diretório gravável.
