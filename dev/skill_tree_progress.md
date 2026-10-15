# Progreso del Árbol de Habilidades

## Estado actual
Estoy trabajando en el árbol de habilidades (skill tree) del juego Pack Tycoon. El árbol tiene 4 ramas con 2 opciones cada una, for a un total de 8 opciones comprables con monedas de rebirth.

## ¿Qué falta por hacer?
- [ ] Revisar que todas las opciones del árbol se visualicen correctamente en el SkillTreePanel
- [ ] Verificar que los costos y efectos de cada nivel sean consistentes con LootDB
- [ ] Probar la compra de niveles desde la interfaz
- [ ] Asegurarme de que el panel se refresca correctamente cuando se compran habilidades

## Ramas y opciones actuales

### 1. CALIDAD DE VIDA (vida)
- **CAIDA RÁPIDA** (caida): Niveles 1-5, reduce el tiempo que tardan las cajas en caer
- **MESA ORDENADA** (orden): Nivel 1, los paquetes y objetos se colocan solos en una rejilla

### 2. GANANCIAS (ganancias)
- **MEJORES VENTAS** (ventas): Niveles 1-5, todo lo vendido vale más
- **DINERO EXTRA** (rasgar): Niveles 1-5, probabilidad de soltar dinero al golpear

### 3. DANO (dano)
- **GOLPE DURO** (golpe): Niveles 1-5, sube el daño de cada golpe
- **GOLPE DOBLE** (doble): Niveles 1-5, probabilidad de que un golpe sea doble daño

### 4. HERENCIA (hereda)
- **SOBRES BARATOS** (barato): Niveles 1-5, todos los sobres cuestan menos
- **DINERO INICIAL** (hereda): Niveles 1-5, cada partida nueva empieza con más dinero

## Next steps
1. Probar la apertura del árbol desde el menú de rebirth
2. Verificar que los costos escalan correctamente (1, 2, 3, 5, 8 monedas por nivel)
3. Comprobar que los efectos se reflejan en el juego (drop time, damage, etc.)
4. Asegurarme de que el panel se cierra correctamente y el foco regresa a la hucha