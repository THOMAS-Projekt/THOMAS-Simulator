# Kompilieranweisungen
include (ValaPrecompile)
vala_precompile (VALA_C
    config.vala
    Application.vala
    MainWindow.vala
    MapWindow.vala
    Widgets/Canvas.vala
    Widgets/MapCanvas.vala
    Backend/Room.vala
    Backend/Robot.vala
    Backend/MappingAlgorithm.vala
PACKAGES
    gtk+-3.0
    gio-2.0
    granite
    posix
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --thread
    --target-glib=2.32
)

# C-Warnungen ausblenden
add_definitions (-w)

# Ausführbare Datei hinzufügen
add_executable (${CMAKE_PROJECT_NAME} ${VALA_C})

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION bin)