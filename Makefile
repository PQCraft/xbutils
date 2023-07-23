CROSS ?= 
SRCDIR ?= src
OBJDIR ?= obj
OUTDIR ?= .

ifndef OS
    ifeq ($(CROSS),)
        CC ?= gcc
        CXX ?= g++
        LD = $(CC)
        AR ?= ar
        STRIP ?= strip
        WINDRES ?= true
        ifndef M32
            PLATFORM := $(subst $() $(),_,$(subst /,_,$(shell uname -s)_$(shell uname -m)))
        else
            PLATFORM := $(subst $() $(),_,$(subst /,_,$(shell i386 uname -s)_$(shell i386 uname -m)))
        endif
    else ifeq ($(CROSS),win32)
        ifndef M32
            CC = x86_64-w64-mingw32-gcc
            CXX = x86_64-w64-mingw32-g++
            LD = $(CC)
            AR = x86_64-w64-mingw32-ar
            STRIP = x86_64-w64-mingw32-strip
            WINDRES = x86_64-w64-mingw32-windres
            PLATFORM := Windows_x86_64
        else
            CC = i686-w64-mingw32-gcc
            CXX = i686-w64-mingw32-g++
            LD = $(CC)
            AR = i686-w64-mingw32-ar
            STRIP = i686-w64-mingw32-strip
            WINDRES = i686-w64-mingw32-windres
            PLATFORM := Windows_i686
        endif
    else
        .PHONY: error
        error:
	        @echo Invalid cross-compilation target: $(CROSS)
	        @exit 1
    endif
    SHCMD = unix
else
    CC = gcc
    CXX = g++
    LD = $(CC)
    AR = ar
    STRIP = strip
    WINDRES = windres
    CROSS = win32
    ifndef M32
        PLATFORM := Windows_x86_64
    else
        PLATFORM := Windows_i686
    endif
    ifdef MSYS2
        SHCMD = unix
    else
        SHCMD = win32
    endif
endif

ifndef DEBUG
    _OBJDIR := release
else
    _OBJDIR := debug
endif
_OBJDIR := $(OBJDIR)/$(_OBJDIR)/$(PLATFORM)

_CFLAGS := $(CFLAGS)
_CXXFLAGS := $(CXXFLAGS)
_CPPFLAGS := $(CPPFLAGS)
_LDFLAGS := $(LDFLAGS)
_LDLIBS := $(LDLIBS) -lm
ifndef DEBUG
    _CFLAGS += -O2
    _CXXFLAGS += -O2
else
    _CFLAGS += -Og -g
    _CXXFLAGS += -Og -g
    ifdef ASAN
        _CFLAGS += -fsanitize=address
        _CXXFLAGS += -fsanitize=address
        _LDFLAGS += -fsanitize=address
    endif
endif

BIN := xbutils
ifeq ($(SHCMD),win32)
    TARGET := .exe
endif
TARGET := $(OUTDIR)/$(BIN)$(TARGET)

.SECONDEXPANSION:

define _rwildcard
$(wildcard $(1)$(2)) $(foreach p,$(wildcard $(1)*),$(call _rwildcard,$(p)/,$(2)))
endef
define rwildcard
$(foreach p,$(1),$(call _rwildcard,$(dir $(p)),$(notdir $(p))))
endef
ifeq ($(SHCMD),win32)
define mkpath
$(subst /,\,$(1))
endef
endif
ifeq ($(SHCMD),unix)
define mkdir
if [ ! -d '$(1)' ]; then echo 'Creating $(1)...'; mkdir -p '$(1)'; fi; true
endef
define rm
if [ -f '$(1)' ]; then echo 'Removing $(1)...'; rm -f '$(1)'; fi; true
endef
define rmdir
if [ -d '$(1)' ]; then echo 'Removing $(1)...'; rm -rf '$(1)'; fi; true
endef
define exec
'$(1)'
endef
else ifeq ($(SHCMD),win32)
define mkdir
if not exist "$(call mkpath,$(1))" echo Creating $(1)... & md "$(call mkpath,$(1))"
endef
define rm
if exist "$(call mkpath,$(1))" echo Removing $(1)... & del /Q "$(call mkpath,$(1))"
endef
define rmdir
if exist "$(call mkpath,$(1))" echo Removing $(1)... & rmdir /S /Q "$(call mkpath,$(1))"
endef
define exec
$(1)
endef
endif
ifeq ($(SHCMD),unix)
define nop
:
endef
define null
/dev/null
endef
else ifeq ($(SHCMD),win32)
define nop
echo. > NUL
endef
define null
NUL
endef
endif
ifndef inc.null
define inc.null
$(null)
endef
endif
define inc.c
$$(patsubst noexist\:,,$$(patsubst $(inc.null),,$$(wildcard $$(shell $(CC) $(CFLAGS) $(CPPFLAGS) -x c -MM $(inc.null) $$(wildcard $(1)) -MT noexist))))
endef
define inc.cpp
$$(patsubst noexist\:,,$$(patsubst $(inc.null),,$$(wildcard $$(shell $(CXX) $(CXXFLAGS) $(CPPFLAGS) -x c -MM $(inc.null) $$(wildcard $(1)) -MT noexist))))
endef

SOURCES := $(call rwildcard, $(SRCDIR)/*.c $(SRCDIR)/*.cpp)
OBJECTS := $(patsubst $(SRCDIR)/%.c,$(_OBJDIR)/%.c.o,$(SOURCES))
OBJECTS := $(patsubst $(SRCDIR)/%.cpp,$(_OBJDIR)/%.cpp.o,$(OBJECTS))

default: $(TARGET)
	@$(nop)

$(OUTDIR):
	@$(call mkdir,$@)

$(_OBJDIR)/%.c.o: $(SRCDIR)/%.c $(call inc,$(SRCDIR)/%.c)
	@echo Compiling $<...
	@$(call mkdir,$(dir $@))
	@$(CC) $(_CFLAGS) $(_CPPFLAGS) $< -c -o $@
	@echo Compiled $<

$(_OBJDIR)/%.cpp.o: $(SRCDIR)/%.cpp $(call inc,$(SRCDIR)/%.cpp)
	@echo Compiling $<...
	@$(call mkdir,$(dir $@))
	@$(CC) $(_CFLAGS) $(_CPPFLAGS) $< -c -o $@
	@echo Compiled $<

$(TARGET): $(OBJECTS) | $(OUTDIR)
	@echo Linking $@...
	@$(LD) $(_LDFLAGS) $^ $(_LDLIBS) -o $@
	@echo Linked $@

clean:
	@$(call rm,$(TARGET))
	@$(call rmdir,$(_OBJDIR))

.PHONY: default clean
