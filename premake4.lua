function fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

newoption {
    trigger     = "embed_kernels",
    description = "Embed CL kernels into binary module"
}

newoption {
    trigger = "use_tbb",
    description = "Use Intel(R) TBB library for multithreading"
}

newoption {
    trigger = "use_embree",
    description = "Use Intel(R) Embree for CPU hit testing"
}

newoption {
    trigger = "package",
    description = "Package the library for a binary release"
}

newoption {
    trigger = "submit",
    description = "Submit FireRays SDK."
}

function build(config)
	if os.is("windows") then
		buildcmd="devenv FireRays.sln /build \"" .. config .. "|x64\""
	else
		config=config .. "_x64"
		buildcmd="make config=" .. config
	end

	return os.execute(buildcmd)
end


if _OPTIONS["package"] then
    print ">> FireRays: Packaging mode"
        os.execute("rm -rf dist")
    os.execute("mkdir dist")
    os.execute("echo $(pwd)")
    os.execute("cd dist && mkdir FireRays && cd FireRays && mkdir include && mkdir lib && cd lib && mkdir x64 && cd .. && mkdir bin && cd bin && mkdir x64 && cd .. && cd include && mkdir math && cd ../.. && mkdir 3rdParty")
    os.execute("cp -r ./FireRays/include ./dist/FireRays/")
        os.execute("cp ./Bin/Release/x64/Fire*.lib ./dist/FireRays/lib/x64")
        os.execute("cp ./Bin/Release/x64/Fire*.dll ./dist/FireRays/bin/x64")
        os.execute("cp ./Bin/Release/x64/libFire*.so ./dist/FireRays/lib/x64")
        os.execute("cp ./Bin/Release/x64/Fire*.dylib ./dist/FireRays/bin/x64")
    os.execute("rm -rf ./App/obj")
    os.execute("rm -rf ./CLW/obj")
    os.execute("cp -r ./App ./dist")
    os.execute("cp -r ./CLW ./dist")
    os.execute("rm -rf ./dist/App/*.vcxproj && rm -rf ./dist/App/*.vcxproj.*")
    os.execute("rm -rf ./dist/App/Makefile && rm -rf ./dist/CLW/Makefile")
    os.execute("rm -rf ./dist/CLW/*.vcxproj && rm -rf ./dist/CLW/*.vcxproj.*")
    os.execute("rm -rf ./dist/CLW/*.lua && rm -rf ./dist/App/*.lua")
    os.execute("cp ./Tools/deploy/premake4.lua ./dist")
    os.execute("cp ./Tools/deploy/OpenCLSearch.lua ./dist")
    os.execute("cp ./Tools/deploy/App.lua ./dist/App")
    os.execute("cp ./Tools/deploy/CLW.lua ./dist/CLW")      
    os.execute("cp -r ./Tools/premake ./dist")
    
    os.execute("cp -r ./3rdParty/freeglut ./dist/3rdParty/")
    os.execute("cp -r ./3rdParty/glew ./dist/3rdParty/")
    os.execute("cp -r ./3rdParty/oiio ./dist/3rdParty/")
    os.execute("cp -r ./3rdParty/oiio16 ./dist/3rdParty/")
    os.execute("cp -r ./Tools/deploy/LICENSE.txt ./dist")
    os.execute("cp -r ./Tools/deploy/README.md ./dist")                  
elseif _OPTIONS["submit"] then
    if os.is("macosx") then
        osPremakeFolder = "osx"
        project = "gmake"
    elseif os.is("windows") then
        osPremakeFolder = "win"
        project = "vs2015"
    else
        osPremakeFolder = "linux64"
        project = "gmake"
    end

	result = os.execute("echo generate project && " .. "\"./Tools/premake/".. osPremakeFolder .. "/premake5\" " .. project .. " --embed_kernels")
	assert(result == 0, "failed to generate project.")

	result = build("release")
	assert(result == 0, "failed to build project.")

	result = os.execute("cd App && \"../Bin/Release/x64/UnitTest64\"")
	assert(result == 0, "Unit tests failed.")
	os.execute("echo packaging && " .. "\"./Tools/premake/".. osPremakeFolder .. "/premake5\" " .. " --package")
	os.execute("cd ../FireRays_SDK/ && git clean -dfx && git checkout .")
	os.execute("cp -r ./dist/* ../FireRays_SDK/")
	os.execute("cd ../FireRays_SDK/ && git add .")
	os.chdir("../FireRays_SDK/")
	result =  os.execute("echo generate project && " .. "\"./premake/".. osPremakeFolder .. "/premake5\" " .. project)
	assert(result == 0, "failed to generate SDK project.")
	result = build("release")
	assert(result == 0, "failed to build SDK.")
	result = os.execute("git commit -m \"Update SDK\"")
	result = os.execute("git push origin master")

else
solution "FireRays"
    configurations { "Debug", "Release" }           
    language "C++"
    flags { "NoMinimalRebuild", "EnableSSE", "EnableSSE2" }
    -- find and add path to Opencl headers
    dofile ("./OpenCLSearch.lua" )
    -- define common includes
    includedirs { ".","./3rdParty/include" }

    -- perform OS specific initializations
    local targetName;
    if os.is("macosx") then
        targetName = "osx"
        platforms {"x64"}
    else
        platforms {"x32", "x64"}
    end
    
    if os.is("windows") then
        targetName = "win"
        defines{ "WIN32" }
        buildoptions { "/MP"  } --multiprocessor build
        defines {"_CRT_SECURE_NO_WARNINGS"}
    elseif os.is("linux") then
        buildoptions {"-fvisibility=hidden"}
    end

    --make configuration specific definitions
    configuration "Debug"
        defines { "_DEBUG" }
        flags { "Symbols" }
    configuration "Release"
        defines { "NDEBUG" }
        flags { "Optimize" }

    configuration {"x64", "Debug"}
        targetsuffix "64D"
    configuration {"x32", "Debug"}
        targetsuffix "D"
    configuration {"x64", "Release"}
        targetsuffix "64"   
    
    configuration {} -- back to all configurations

    if fileExists("./FireRays/FireRays.lua") then
        dofile("./FireRays/FireRays.lua")
    end
    
    if fileExists("./Gtest/gtest.lua") then
        dofile("./Gtest/gtest.lua")
    end
    
    if fileExists("./UnitTest/UnitTest.lua") then
        dofile("./UnitTest/UnitTest.lua")
    end
    
    if fileExists("./CLW/CLW.lua") then
        dofile("./CLW/CLW.lua")
    end
    
    if fileExists("./App/App.lua") then
        dofile("./App/App.lua")
    end

    if fileExists("./Calc/Calc.lua") then
        dofile("./Calc/Calc.lua")
    end
end
