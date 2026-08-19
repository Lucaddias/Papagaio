# Cria o target PapagaioTests (unit test bundle, host = app) e liga no scheme.
# Uso: ruby Scripts/adiciona-target-de-testes.rb
require "xcodeproj"

PROJ = "Loro.xcodeproj"
proj = Xcodeproj::Project.open(PROJ)

app = proj.targets.find { |t| t.name == "Loro" } || abort("target Loro não encontrado")

if proj.targets.any? { |t| t.name == "PapagaioTests" }
  # Já existe: garante só o ajuste de link do app (export_dynamic), que é o
  # que deixa o bundle enxergar os símbolos do módulo hospedeiro.
  app.build_configurations.each do |cfg|
    flags = Array(cfg.build_settings["OTHER_LDFLAGS"])
    flags += ["-Wl,-export_dynamic"] unless flags.include?("-Wl,-export_dynamic")
    cfg.build_settings["OTHER_LDFLAGS"] = flags
  end
  proj.save
  abort("PapagaioTests já existe — export_dynamic garantido")
end

# O bundle de testes resolve os símbolos do módulo Papagaio dentro do
# hospedeiro em runtime; sem export_dynamic o link do bundle falha com
# "Undefined symbols Papagaio.…".
app.build_configurations.each do |cfg|
  flags = Array(cfg.build_settings["OTHER_LDFLAGS"])
  flags += ["-Wl,-export_dynamic"] unless flags.include?("-Wl,-export_dynamic")
  cfg.build_settings["OTHER_LDFLAGS"] = flags
end

# O app compila como módulo "Papagaio" para os testes usarem
# `@testable import Papagaio` como escrito (o produto segue sendo Loro.app).
app.build_configurations.each do |cfg|
  cfg.build_settings["PRODUCT_MODULE_NAME"] = "Papagaio"
end

tests = proj.new_target(
  :unit_test_bundle,
  "PapagaioTests",
  :osx,
  "26.0",
  nil,
  :swift
)
tests.add_dependency(app)

# Os testes importam PapagaioCore direto: o produto do pacote precisa
# estar ligado também (o mesmo que o app usa).
core = app.package_product_dependencies.find { |d| d.product_name == "PapagaioCore" }
tests.package_product_dependencies << core if core

# Grupo espelhando a pasta no disco.
grupo = proj.main_group["PapagaioTests"] ||
        proj.main_group.new_group("PapagaioTests", "PapagaioTests")
%w[BibliotecaTests.swift InterfaceTests.swift].each do |nome|
  ref = grupo.new_reference(nome)
  tests.source_build_phase.add_file_reference(ref)
end

# Frameworks do app precisam estar visíveis ao bundle de testes.
tests.build_configurations.each do |cfg|
  s = cfg.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"] = "com.papagaio.tests"
  s["PRODUCT_NAME"] = "$(TARGET_NAME)"
  s["GENERATE_INFOPLIST_FILE"] = "YES"
  s["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/Loro.app/Contents/MacOS/Loro"
  s["SWIFT_VERSION"] = "6.0"
  s["MACOSX_DEPLOYMENT_TARGET"] = "26.0"
  s["CODE_SIGN_STYLE"] = "Automatic"
  s.delete("INFOPLIST_FILE")
end

# Os símbolos do módulo Papagaio vivem no hospedeiro: o bundle os resolve
# em runtime, então o link não pode exigir resolução imediata.
tests.build_configurations.each do |cfg|
  flags = Array(cfg.build_settings["OTHER_LDFLAGS"])
  flags += ["-undefined", "dynamic_lookup"] unless flags.include?("dynamic_lookup")
  cfg.build_settings["OTHER_LDFLAGS"] = flags
end

# Liga no Test action do scheme Loro.
scheme_path = File.join(PROJ, "xcshareddata/xcschemes/Loro.xcscheme")
scheme = Xcodeproj::XCScheme.new(scheme_path)
scheme.add_test_target(tests)
scheme.save!

proj.save
puts "ok: target PapagaioTests criado e ligado no scheme"
