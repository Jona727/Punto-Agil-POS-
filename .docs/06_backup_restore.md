# Copia de Seguridad y Restauración (Backup)

## Objetivo
Garantizar la persistencia de la información ante la eventual pérdida de un dispositivo, salvaguardando el negocio del cliente.

## Requerimientos Técnicos
1. **Local storage**: Las bases de datos de Hive son archivos físicos `.hive`.
2. **Exportación**:
   - Empacar los archivos de `productsBox` y `salesBox` en un archivo `.zip`.
   - Ofrecer la descarga mediante el sistema de archivos compartido.
3. **Restauración**:
   - Opción para "Importar Backup".
   - Validar que sea un archivo válido antes de sobreescribir las cajas activas.

## Beneficios
- Alta seguridad y confianza del usuario.
- Independencia total de servidores.
