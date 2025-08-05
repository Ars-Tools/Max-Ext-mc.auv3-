//#include<Foundation/Foundation.h>
#include"ext.h"
#include"ext_obex.h"
#include"z_dsp.h"
#include<CoreAudio/CoreAudio.h>
#include<CoreMIDI/CoreMIDI.h>
#include<simd/simd.h>
#include<Accelerate/Accelerate.h>
typedef struct {
	t_pxobject const super;
	void * const core;
	void * const outlet;
	struct {
		long const layout[64];
		long const length;
	} const i, o;
} t_auv3;
C74_HIDDEN t_class const * class = NULL;
extern void * const core_new(t_pxobject const*const);
extern void core_del(void const*const);
extern void core_load(void const*const, uint32_t const, uint32_t const, uint32_t const);
extern void core_unload(void const*const);
extern void core_reload(void const*const);
extern void core_dblclick(void const*const);
extern bool core_setup(void const*const, double const, long const, long const*const, long const, long const*const, long const);
extern void core_bypass(void const*const, bool const);
extern void core_dsp(void const*const this,
					 double const*const*const ins, long const numins,
					 double      *const*const out, long const numout,
					 long const length, void const*const parameter);
extern void core_parameter(void const*const, long const, double const);
extern void core_note(void const*const, uint8_t const, uint8_t const, uint8_t const, uint8_t const);
extern void core_preset(void const*const, char const, long const);
extern void core_midi(void const*const, uint8_t const*const, long const);
C74_HIDDEN t_auv3 const*const new(t_symbol const*const symbol, short const argc, t_atom*const argv) {
	register t_auv3 * const object = (t_auv3*const)object_alloc((t_class*const)class);
	if (object) {
		attr_args_process(object, argc, argv);
		*(void const**const)&object->core = core_new(&object->super);
		
		// Inlets
//		inlet_new(object, "list");
//		inlet_new(object, "list");
		if ( 0 < object->i.length )
			z_dsp_setup((t_pxobject*const)object, object->i.length );
		*(short*const)&object->super.z_misc |= Z_MC_INLETS|Z_NO_INPLACE;
		
		// Outlets
		*(void const**const)&object->outlet = listout(object);
		for ( register long k = 0, K = object->o.length ; k < K ; ++ k )
			outlet_new(object, "multichannelsignal");
	}
	return object;
}
C74_HIDDEN void del(t_auv3 const*const this) {
	outlet_delete(this->outlet);
	core_del(this->core);
}
C74_HIDDEN void load_in(t_auv3 const*const this, long const type, long const subtype, long const manufacturer) {
	core_load(this->core, (uint32_t const)type, (uint32_t const)subtype, (uint32_t const)manufacturer);
	core_load(this->core, (uint32_t const)type, (uint32_t const)subtype, (uint32_t const)manufacturer);
}
C74_HIDDEN void load_out(t_auv3 const*const this, long const type, long const subtype, long const manufacturer) {
	t_atom argv[3] = {0};
	atom_setlong_array(3, argv, 3, (t_atom_long[]){type, subtype, manufacturer});
	outlet_anything(this->outlet, gensym("load"), 3, argv);
}
C74_HIDDEN void unload(t_auv3 const*const this) {
	core_unload(this->core);
	outlet_anything(this->outlet, gensym("unload"), 0, nil);
}
C74_HIDDEN void reload(t_auv3 const*const this) {
	core_reload(this->core);
	outlet_anything(this->outlet, gensym("reload"), 0, nil);
}
C74_HIDDEN void dblclick(t_auv3 const*const this) {
	core_dblclick(this->core);
}
C74_HIDDEN void assist(t_auv3 const*const this, void const*const _, long const scope, long const index, char * const string) {
	switch (scope) {
		case ASSIST_INLET:
			if (!index)
				sprintf(string, "Primary Input Bus, Parameter, MIDI and AUv3 General MSGs");
			else if (index < this->i.length)
				sprintf(string, "Input Bus %ld of Audio Unit (V3)", index);
			break;
		case ASSIST_OUTLET:
			if (this->o.length <= index)
				sprintf(string, "General Output\r\nParameter, MIDI and AUv3 General MSGs");
			else if (!index)
				sprintf(string, "Primary Output Bus");
			else
				sprintf(string, "Output Bus %ld of Audio Unit (V3)", index);
			break;
	}
}
C74_HIDDEN void clr(t_auv3 const*const this, t_object const*const dsp64,
					double const*const*const ins, long const numins,
					double      *const*const out, long const numout,
					long const length, long const flags,
					void*const parameter) {
	for ( register long k = 0, K = numout ; k < K ; ++ k )
		vDSP_vclrD(out[k], 1, length);
}
C74_HIDDEN void bypass(t_auv3 const*const this, long const flag) {
	core_bypass(this->core, flag);
}
C74_HIDDEN void routine64(t_auv3 const*const this, t_object const*const dsp64,
						  double const*const*const ins, long const numins,
						  double      *const*const out, long const numout,
						  long const length, long const flags,
						  void const*const parameter) {
	core_dsp(this->core,
			 ins, numins,
			 out, numout,
			 length, parameter);
}
C74_HIDDEN void dsp64(t_auv3 const*const this, t_object const*const dsp64, short const*const count, double const samplerate, long const vectorsize, long const flags) {
//	object_post(this, "In: %d, Out: %d", this->i.length, this->o.length);
	dsp_add64((t_object*const)dsp64,
			  (t_object*const)this,
			  core_setup(this->core, samplerate, vectorsize,
						 this->i.layout, this->i.length,
						 this->o.layout, this->o.length) ? (t_perfroutine64 const)routine64 : (t_perfroutine64 const)clr,
			  0,
			  nil);
}
C74_HIDDEN long input(t_auv3 const*const this, long const index, long const count) {
	return this->i.layout[index] == count;
}
C74_HIDDEN long output(t_auv3 const*const this, long const index) {
	return this->o.layout[index];
}
C74_HIDDEN void parameter_in(t_auv3 const*const this, long const address, double const value) {
	core_parameter(this->core, address, value);
}
C74_HIDDEN void parameter_out(t_auv3 const*const this, UInt64 const addr, Float64 const value) {
	t_atom argv[2] = {0};
	atom_setlong(argv + 0, addr);
	atom_setfloat(argv + 1, value);
	outlet_anything(this->outlet, gensym("parameter"), 2, argv);
}
C74_HIDDEN void note(t_auv3 const*const this, long const note, long const velocity, long const channel, long const group) {
	core_note(this->core, note, velocity, channel, group);
}
C74_HIDDEN void midi_in(t_auv3 const*const this, t_symbol const*const msg, long const argc, t_atom const*const argv) {
	C74_ASSERT(msg == gensym("midi"))
	uint8_t*const payload = (uint8_t*const)sysmem_newptr(argc);
	atom_getchar_array(argc, argv, argc, payload);
	core_midi(this->core, payload, argc);
	sysmem_freeptr(payload);
}
C74_HIDDEN void midi_out(t_auv3 const*const this, uint8_t const*const msg, uint64_t const count) {
	t_atom*const argv = (t_atom*const)sysmem_newptr(count * sizeof(t_atom const));
	atom_setsym(argv, gensym("midi"));
	atom_setchar_array(count, argv, count, (uint8_t*const)msg);
	outlet_anything(this->outlet, gensym("midi"), count, argv);
	sysmem_freeptr(argv);
}
C74_HIDDEN void preset_in(t_auv3 const*const this, t_symbol const*const msg, long const argc, t_atom const*const argv) {
	// 0b000 preset factory
	// 0b001 preset edit
	// 0b010 preset dump
	// 0b100 preset load
	// 0b101 preset save
	// 0b110 preset create
	// 0b111 preset delete
	switch (argc) {
	case 2:
		if (atom_gettype(argv + 0) != A_SYM && atom_gettype(argv + 1) != A_LONG);
		else if (atom_getsym(argv) == gensym("factory"))
			core_preset(this->core, 0b000, atom_getlong(argv + 1));
		else if (atom_getsym(argv) == gensym("load"))
			core_preset(this->core, 0b100, atom_getlong(argv + 1));
		else if (atom_getsym(argv) == gensym("save"))
			core_preset(this->core, 0b101, atom_getlong(argv + 1));
	}
}
C74_HIDDEN void preset_out(t_auv3 const*const this, char const*const str, long const index) {
	t_atom list[2] = {0};
	atom_setsym(list, gensym(str));
	atom_setlong(list + 1, index);
	outlet_anything(this->outlet, gensym("preset"), 2, list);
}
C74_EXPORT void ext_main(void*const _) {
	if (!class) {
		//
		t_class * const object = (t_class*const)class_new("mc.auv3~", (method const)new, (method const)del, sizeof(t_auv3 const), 0L, A_GIMME, 0);
		
		// DSP relations
		class_addmethod(object, (method const)bypass, "bypass", A_DEFLONG, 0);
		class_addmethod(object, (method const)dsp64, "dsp64", A_CANT, 0);
		class_addmethod(object, (method const)input, "inputchanged", A_CANT, 0);
		class_addmethod(object, (method const)output, "multichanneloutputs", A_CANT, 0);
		
		// Load & Unload
		class_addmethod(object, (method const)load_in, "load", A_LONG, A_LONG, A_LONG, 0);
		class_addmethod(object, (method const)unload, "unload", 0);
		class_addmethod(object, (method const)reload, "reload", 0);
		
		// Parameters
		class_addmethod(object, (method const)parameter_in, "parameter", A_LONG, A_FLOAT, 0);
		
		// MIDI
		class_addmethod(object, (method const)midi_in, "midi", A_GIMME, 0);
		
		// NOTE
		class_addmethod(object, (method const)note, "note", A_LONG, A_LONG, A_DEFLONG, A_DEFLONG, 0);
		
		// Preset
		class_addmethod(object, (method const)preset_in, "preset", A_GIMME, 0);
		
		// Show UI
		class_addmethod(object, (method const)dblclick, "dblclick", A_CANT, 0);
		
		// Assist
		class_addmethod(object, (method const)assist, "assist", A_CANT, 0);
		
		// Attributes
		class_addattr(object, attr_offset_array_new("in", gensym("long"), 32, 0, (method const)0L,(method const)0L, offsetof(t_auv3 const, i.length), offsetof(t_auv3 const, i.layout)));
		class_addattr(object, attr_offset_array_new("out", gensym("long"), 32, 0, (method const)0L, (method const)0L, offsetof(t_auv3 const, o.length), offsetof(t_auv3 const, o.layout)));

		// DSP Initialisation
		class_dspinit(object);
		
		// Register
		class_register(CLASS_BOX, object);
		class = object;
	}
}
