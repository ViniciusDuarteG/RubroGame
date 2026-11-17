# Assets próprios — revisão visual de 17/11/2026

Texturas criadas com a ferramenta integrada **imagegen**, sem imagens de referência ou arquivos extraídos de Battlefield 2. Atlas original: `assets/textures/source/military-atlas.png`. Tiles usados pelo jogo: `assets/textures/{ground,concrete,metal,fabric,asphalt,camo}-v2.png`, cada um com 512 × 512 pixels e mipmaps. O atlas-fonte é excluído dos builds; a cópia de runtime `assets/textures/military-atlas.png` permite desenhar cada soldado em uma única superfície. `python3 tools/import_atlas.py` apenas separa os seis tiles; Pillow é necessário somente para essa operação de desenvolvimento.

Prompt final enviado à ferramenta integrada:

> Use case: stylized-concept. Asset type: production diffuse texture atlas for an original low-poly military FPS with the grounded, dusty visual feel of 2005 PC games. Generate one square 1536px texture sheet, exactly 3 columns by 2 rows of equal square material tiles, no borders, gaps, labels, letters, logos, objects or perspective. Orthographic flat surface scans, evenly lit, diffuse color only, no directional shadows, no specular highlights. Top left: pale beige dusty packed earth, subtle gravel and scuffs. Top middle: sunbleached warm gray concrete plaster with tiny chips, grunge at several scales. Top right: matte olive drab painted steel with fine scratches, restrained rust.

A saída entregue foi um atlas 1536 × 1024, organizado em três colunas e duas linhas. O texto acima registra o pedido; a dimensão efetivamente recebida é a utilizada pelo importador.

Geometria original em GDScript: `scripts/model_kit.gd` produz formas chanfradas e afuniladas para soldados e arma; `scripts/architecture.gd` acrescenta platibandas, molduras, calhas, soleiras, acostamentos e drenagem. O jipe recebeu grade, para-choques, espelhos, estrutura superior e painel. Tudo é consolidado em malhas na carga; as regras de dano, navegação e captura permanecem compartilhadas entre solo e LAN.

As coordenadas UV são projetadas uma vez durante a consolidação. Os soldados compartilham um atlas, com o índice de material no canal alfa dos vértices. A renderização usa uma amostra difusa por superfície em vez de projeção triplanar por pixel. Não há normal maps, iluminação volumétrica ou texturas 4K.
