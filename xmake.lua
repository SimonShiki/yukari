set_project("yukari")
set_version("0.1.0")
set_defaultmode("release")
set_allowedplats("windows", "linux", "android")
set_allowedarchs(
    "windows|x64",
    "linux|x86_64",
    "linux|arm64",
    "android|arm64-v8a",
    "android|x86_64"
)

local easytier_version = "0.1.0"
local rust_version = "1.95.0"
local android_api = "24"

local build_targets = {
    windows = {
        x64 = {triple = "x86_64-pc-windows-msvc", library = "easytier_ffi.dll"}
    },
    linux = {
        x86_64 = {triple = "x86_64-unknown-linux-gnu", library = "libeasytier_ffi.so"},
        arm64 = {triple = "aarch64-unknown-linux-gnu", library = "libeasytier_ffi.so"}
    },
    android = {
        ["arm64-v8a"] = {triple = "aarch64-linux-android", abi = "arm64-v8a", library = "libeasytier_ffi.so"},
        x86_64 = {triple = "x86_64-linux-android", abi = "x86_64", library = "libeasytier_ffi.so"}
    }
}

package("protobuf-tools")
    set_kind("binary")

    on_fetch(function (package)
        import("lib.detect.find_tool")
        -- Try to find system protoc first
        local protoc = find_tool("protoc", {version = true})
        if protoc and protoc.program then
            return {program = protoc.program}
        end
    end)

    if is_host("windows") then
        add_urls("https://github.com/protocolbuffers/protobuf/releases/download/v$(version)/protoc-$(version)-win64.zip")
        add_versions("35.1", "5d3ff218d7d91eea95f7569bcb5a98f3030f8996d44151279d9772edcff76082")
    elseif is_host("macosx") then
        if os.arch() == "arm64" then
            add_urls("https://github.com/protocolbuffers/protobuf/releases/download/v$(version)/protoc-$(version)-osx-aarch_64.zip")
            add_versions("35.1", "7f5a62e1e6c288de2cff85c5c92e515a6a5c37e93d6bf88c5e8e111b6e3f5a42")
        else
            add_urls("https://github.com/protocolbuffers/protobuf/releases/download/v$(version)/protoc-$(version)-osx-x86_64.zip")
            add_versions("35.1", "d8003c88b6c8e7c66f5ae7c0d62c0a3a8cdb5e3d7f3a8e8c8c5e8f8b8c5e3d7f")
        end
    elseif os.arch() == "arm64" or os.arch() == "aarch64" then
        add_urls("https://github.com/protocolbuffers/protobuf/releases/download/v$(version)/protoc-$(version)-linux-aarch_64.zip")
        add_versions("35.1", "01bf9d08808c7f96678b63f4bd8efa559bb4f83d5a7a270d5edaf507f9d5d9cf")
    else
        add_urls("https://github.com/protocolbuffers/protobuf/releases/download/v$(version)/protoc-$(version)-linux-x86_64.zip")
        add_versions("35.1", "6930ebf62bd4ea607b98fff052596c6ee564b9835b4ce172c75a3f53ae9d91b7")
    end

    on_install("@windows", "@linux", "@macosx", function (package)
        os.cp("bin/*", package:installdir("bin"))
        os.cp("include/*", package:installdir("include"))
        package:addenv("PATH", "bin")
    end)
package_end()

package("easytier-ffi")
    set_kind("library")
    set_homepage("https://github.com/EasyTier/EasyTier")
    set_license("LGPL-3.0")
    add_urls("https://github.com/EasyTier/EasyTier.git", {submodules = false})
    add_versions(easytier_version, "7223677264f1d99f55b9c30888d09ccbf55671c3")
    add_deps("protobuf-tools 35.1", {host = true, private = true})

    if is_plat("windows") then
        add_resources(easytier_version, "vc-ltl",
            "https://github.com/Chuyu-Team/VC-LTL5/releases/download/v5.2.2/VC-LTL-Binary.7z",
            "04aa46a7d2af655bcf42c4937504525eb7e66a75910ed42fd25a1cdcec587df0")
        add_resources(easytier_version, "yy-thunks",
            "https://github.com/Chuyu-Team/YY-Thunks/releases/download/v1.1.7/YY-Thunks-Objs.zip",
            "c3066f3f074ebc2a89b2def5f427bdea238dee17349d2bab579af519781691ab")
    end

    on_install("windows|x64", "linux|x86_64", "linux|arm64", "android|arm64-v8a", "android|x86_64", function (package)
        import("lib.detect.find_tool")
        import("core.project.config", {alias = "project_config"})

        local config = assert(build_targets[package:plat()] and build_targets[package:plat()][package:arch()],
            "unsupported target: %s|%s", package:plat(), package:arch())

        -- Find clang using xmake's detection
        local clang_tool = find_tool("clang", {version = true})
        assert(clang_tool and clang_tool.program, "clang was not found in PATH. Please install LLVM/Clang")
        local clang = clang_tool.program

        -- Find libclang library directory
        local libclang
        local libclang_name = is_host("windows") and "libclang.dll" or "libclang.so"

        -- Search in multiple possible locations
        local search_paths = {}
        if os.getenv("LLVM_ROOT") then
            local llvm_root = os.getenv("LLVM_ROOT")
            table.insert(search_paths, path.join(llvm_root, is_host("windows") and "bin" or "lib"))
            table.insert(search_paths, path.join(llvm_root, "lib64"))
        end

        -- Paths relative to clang binary
        local clang_dir = path.directory(clang)
        table.insert(search_paths, path.join(clang_dir, "..", "lib"))
        table.insert(search_paths, path.join(clang_dir, "..", "lib64"))
        if is_host("windows") then
            table.insert(search_paths, clang_dir)
        end

        -- System-wide paths
        table.insert(search_paths, "/usr/lib")
        table.insert(search_paths, "/usr/lib64")
        table.insert(search_paths, "/usr/local/lib")

        for _, search_path in ipairs(search_paths) do
            local test_path = path.join(search_path, libclang_name)
            if os.isfile(test_path) or os.islink(test_path) then
                libclang = search_path
                break
            end
        end

        assert(libclang, "libclang was not found. Please install LLVM/Clang development files or set LLVM_ROOT")

        local protoc = path.join(package:dep("protobuf-tools"):installdir("bin"),
            is_host("windows") and "protoc.exe" or "protoc")
        os.cp(path.join(package:dep("protobuf-tools"):installdir("include", "google")),
            path.join(os.curdir(), "easytier-proto", "proto"))
        local cargo_target_dir = path.join(package:builddir(), "cargo")
        local resource_dir = os.iorunv(clang, {"-print-resource-dir"}):trim()
        local envs = {
            BINDGEN_EXTRA_CLANG_ARGS = string.format('--target=%s -resource-dir="%s"', config.triple, resource_dir),
            CARGO_TARGET_DIR = cargo_target_dir,
            CLANG_PATH = clang,
            LIBCLANG_PATH = libclang,
            PROTOC = protoc
        }
        local cargo_args = {"+" .. rust_version}

        if package:is_plat("windows") then
            local cl = assert(package:tool("cc"), "cl.exe was not found")
            local link = assert(package:tool("ld"), "link.exe was not found")
            local lib = path.join(path.directory(cl), "lib.exe")
            assert(os.isfile(lib), "lib.exe was not found at %s", lib)
            envs.AR_x86_64_pc_windows_msvc = lib
            envs.CC_x86_64_pc_windows_msvc = cl
            envs.CXX_x86_64_pc_windows_msvc = cl
            envs.CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER = link
            envs.LIB = path.join(os.curdir(), "easytier", "third_party", "x86_64") .. path.envsep() .. (os.getenv("LIB") or "")
            envs.RUSTFLAGS = "-C target-feature=+crt-static"
            envs.VC_LTL = package:resourcedir("vc-ltl")
            envs.YY_THUNKS = package:resourcedir("yy-thunks")
            envs = os.joinenvs(package:toolchain("msvc"):runenvs(), envs)
        elseif package:is_plat("linux") then
            envs.CC = assert(package:tool("cc"), "gcc was not found")
            envs.CXX = assert(package:tool("cxx"), "g++ was not found")
            envs.RUSTFLAGS = "-C target-cpu=generic"
        else
            local ndk = assert(project_config.get("ndk") or os.getenv("ANDROID_NDK_HOME"),
                "Android NDK was not found; configure xmake with --ndk or set ANDROID_NDK_HOME")

            -- Detect host architecture for NDK prebuilt path
            local ndk_host_arch = os.arch()
            local ndk_host = is_host("windows") and "windows-x86_64"
                or (is_host("macosx") and "darwin-x86_64")
                or (ndk_host_arch == "arm64" and "linux-aarch64" or "linux-x86_64")

            local prebuilt_dir = path.join(ndk, "toolchains", "llvm", "prebuilt", ndk_host)
            assert(os.isdir(prebuilt_dir), "NDK prebuilt directory not found: %s", prebuilt_dir)

            local sysroot = path.join(prebuilt_dir, "sysroot")
            local tools = path.join(package:builddir(), "tools")
            os.vrunv("cargo", {"+" .. rust_version, "install", "cargo-ndk", "--version", "4.1.2", "--locked", "--root", tools})
            envs.ANDROID_NDK_HOME = ndk
            envs.ANDROID_NDK_ROOT = ndk
            envs.BINDGEN_EXTRA_CLANG_ARGS = string.format('--sysroot="%s" --target=%s -D__ANDROID_API__=%s',
                sysroot, config.triple, android_api)
            envs.PATH = path.join(tools, "bin") .. path.envsep() .. os.getenv("PATH")
            envs.RUSTFLAGS = "-C link-arg=-Wl,-z,max-page-size=16384 -C link-arg=-Wl,-z,common-page-size=16384"
            table.join2(cargo_args, {"ndk", "--target", config.abi, "--platform", android_api})
        end

        table.join2(cargo_args, {"build", "--locked", "--release", "--lib", "--package", "easytier-ffi"})
        if not package:is_plat("android") then
            table.join2(cargo_args, {"--target", config.triple})
        end
        os.vrunv("cargo", cargo_args, {envs = envs})

        local output_dir = package:is_plat("windows") and "bin" or "lib"
        os.cp(path.join(cargo_target_dir, config.triple, "release", config.library), package:installdir(output_dir))
        if package:is_plat("windows") then
            for _, runtime_file in ipairs({"Packet.dll", "wintun.dll", "WinDivert64.sys"}) do
                os.cp(path.join(os.curdir(), "easytier", "third_party", "x86_64", runtime_file),
                    package:installdir(output_dir))
            end
        end
    end)
package_end()

add_requires("easytier-ffi " .. easytier_version, {system = false})

target("easytier_ffi")
    set_kind("shared")
    add_packages("easytier-ffi")
    on_build(function (target)
        local package = assert(target:pkg("easytier-ffi"))
        local source_dir = is_plat("windows") and "bin" or "lib"
        os.mkdir(path.directory(target:targetfile()))
        os.cp(path.join(package:installdir(), source_dir, path.filename(target:targetfile())), target:targetfile())
        if is_plat("windows") then
            for _, runtime_file in ipairs({"Packet.dll", "wintun.dll", "WinDivert64.sys"}) do
                local runtime_path = path.join(package:installdir(), source_dir, runtime_file)
                if os.isfile(runtime_path) then
                    os.cp(runtime_path, path.directory(target:targetfile()))
                end
            end
        end
    end)
