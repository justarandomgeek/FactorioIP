﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FactorioIP
{
    partial class SignalMap
    {
        public static SignalMap Feathernet_0_17 = new SignalMap(new SignalMap.SignalID[] {
                    ("virtual","signal-grey"),
                    ("virtual","signal-white"),

                    ("virtual","signal-0"),
                    ("virtual","signal-1"),
                    ("virtual","signal-2"),
                    ("virtual","signal-3"),
                    ("virtual","signal-4"),
                    ("virtual","signal-5"),
                    ("virtual","signal-6"),
                    ("virtual","signal-7"),
                    ("virtual","signal-8"),
                    ("virtual","signal-9"),
                    ("virtual","signal-A"),
                    ("virtual","signal-B"),
                    ("virtual","signal-C"),
                    ("virtual","signal-D"),
                    ("virtual","signal-E"),
                    ("virtual","signal-F"),
                    ("virtual","signal-G"),
                    ("virtual","signal-H"),
                    ("virtual","signal-I"),
                    ("virtual","signal-J"),
                    ("virtual","signal-K"),
                    ("virtual","signal-L"),
                    ("virtual","signal-M"),
                    ("virtual","signal-N"),
                    ("virtual","signal-O"),
                    ("virtual","signal-P"),
                    ("virtual","signal-Q"),
                    ("virtual","signal-R"),
                    ("virtual","signal-S"),
                    ("virtual","signal-T"),
                    ("virtual","signal-U"),
                    ("virtual","signal-V"),
                    ("virtual","signal-W"),
                    ("virtual","signal-X"),
                    ("virtual","signal-Y"),
                    ("virtual","signal-Z"),
                    ("virtual","signal-red"),
                    ("virtual","signal-green"),
                    ("virtual","signal-blue" ),
                    ("virtual","signal-yellow" ),
                    ("virtual","signal-pink" ),
                    ("virtual","signal-cyan" ),
                    ("virtual","signal-check" ),
                    ("virtual","signal-dot" ),
                    ("virtual","signal-info" ),

                    ("fluid","water"),
                    ("fluid","crude-oil"),
                    ("fluid","steam"),
                    ("fluid","heavy-oil"),
                    ("fluid","light-oil"),
                    ("fluid","petroleum-gas"),
                    ("fluid","sulfuric-acid"),
                    ("fluid","lubricant"),

                    ("item","wooden-chest"),
                    ("item","iron-chest"),
                    ("item","steel-chest"),
                    ("item","storage-tank"),
                    ("item","transport-belt"),
                    ("item","fast-transport-belt"),
                    ("item","express-transport-belt"),
                    ("item","underground-belt"),
                    ("item","fast-underground-belt"),
                    ("item","express-underground-belt"),
                    ("item","splitter"),
                    ("item","fast-splitter"),
                    ("item","express-splitter"),
                    ("item","burner-inserter"),
                    ("item","inserter"),
                    ("item","long-handed-inserter"),
                    ("item","fast-inserter"),
                    ("item","filter-inserter"),
                    ("item","stack-inserter"),
                    ("item","stack-filter-inserter"),
                    ("item","small-electric-pole"),
                    ("item","medium-electric-pole"),
                    ("item","big-electric-pole"),
                    ("item","substation"),
                    ("item","pipe"),
                    ("item","pipe-to-ground"),
                    ("item","pump"),
                    ("item","rail"),
                    ("item","train-stop"),
                    ("item","rail-signal"),
                    ("item","rail-chain-signal"),
                    ("item","locomotive"),
                    ("item","cargo-wagon"),
                    ("item","fluid-wagon"),
                    ("item","artillery-wagon"),
                    ("item","car"),
                    ("item","tank"),
                    ("item","logistic-robot"),
                    ("item","construction-robot"),
                    ("item","logistic-chest-active-provider"),
                    ("item","logistic-chest-passive-provider"),
                    ("item","logistic-chest-storage"),
                    ("item","logistic-chest-buffer"),
                    ("item","logistic-chest-requester"),
                    ("item","roboport"),
                    ("item","small-lamp"),
                    ("item","red-wire"),
                    ("item","green-wire"),
                    ("item","arithmetic-combinator"),
                    ("item","decider-combinator"),
                    ("item","constant-combinator"),
                    ("item","power-switch"),
                    ("item","programmable-speaker"),
                    ("item","stone-brick"),
                    ("item","concrete"),
                    ("item","hazard-concrete"),
                    ("item","refined-concrete"),
                    ("item","refined-hazard-concrete"),
                    ("item","landfill"),
                    ("item","cliff-explosives"),
                    ("item","repair-pack"),
                    ("item","blueprint"),
                    ("item","deconstruction-planner"),
                    ("item","upgrade-planner"),
                    ("item","blueprint-book"),
                    ("item","boiler"),
                    ("item","steam-engine"),
                    ("item","steam-turbine"),
                    ("item","solar-panel"),
                    ("item","accumulator"),
                    ("item","nuclear-reactor"),
                    ("item","heat-exchanger"),
                    ("item","heat-pipe"),
                    ("item","burner-mining-drill"),
                    ("item","electric-mining-drill"),
                    ("item","offshore-pump"),
                    ("item","pumpjack"),
                    ("item","stone-furnace"),
                    ("item","steel-furnace"),
                    ("item","electric-furnace"),
                    ("item","assembling-machine-1"),
                    ("item","assembling-machine-2"),
                    ("item","assembling-machine-3"),
                    ("item","oil-refinery"),
                    ("item","chemical-plant"),
                    ("item","centrifuge"),
                    ("item","lab"),
                    ("item","beacon"),
                    ("item","speed-module"),
                    ("item","speed-module-2"),
                    ("item","speed-module-3"),
                    ("item","effectivity-module"),
                    ("item","effectivity-module-2"),
                    ("item","effectivity-module-3"),
                    ("item","productivity-module"),
                    ("item","productivity-module-2"),
                    ("item","productivity-module-3"),
                    ("item","wood"),
                    ("item","coal"),
                    ("item","stone"),
                    ("item","iron-ore"),
                    ("item","copper-ore"),
                    ("item","uranium-ore"),
                    ("item","raw-fish"),
                    ("item","iron-plate"),
                    ("item","copper-plate"),
                    ("item","solid-fuel"),
                    ("item","steel-plate"),
                    ("item","plastic-bar"),
                    ("item","sulfur"),
                    ("item","battery"),
                    ("item","explosives"),
                    ("item","crude-oil-barrel"),
                    ("item","heavy-oil-barrel"),
                    ("item","light-oil-barrel"),
                    ("item","lubricant-barrel"),
                    ("item","petroleum-gas-barrel"),
                    ("item","sulfuric-acid-barrel"),
                    ("item","water-barrel"),
                    ("item","copper-cable"),
                    ("item","iron-stick"),
                    ("item","iron-gear-wheel"),
                    ("item","empty-barrel"),
                    ("item","electronic-circuit"),
                    ("item","advanced-circuit"),
                    ("item","processing-unit"),
                    ("item","engine-unit"),
                    ("item","electric-engine-unit"),
                    ("item","flying-robot-frame"),
                    ("item","satellite"),
                    ("item","rocket-control-unit"),
                    ("item","low-density-structure"),
                    ("item","rocket-fuel"),
                    ("item","nuclear-fuel"),
                    ("item","uranium-235"),
                    ("item","uranium-238"),
                    ("item","uranium-fuel-cell"),
                    ("item","used-up-uranium-fuel-cell"),
                    ("item","automation-science-pack"),
                    ("item","logistic-science-pack"),
                    ("item","military-science-pack"),
                    ("item","chemical-science-pack"),
                    ("item","production-science-pack"),
                    ("item","utility-science-pack"),
                    ("item","space-science-pack"),
                    ("item","pistol"),
                    ("item","submachine-gun"),
                    ("item","shotgun"),
                    ("item","combat-shotgun"),
                    ("item","rocket-launcher"),
                    ("item","flamethrower"),
                    ("item","land-mine"),
                    ("item","firearm-magazine"),
                    ("item","piercing-rounds-magazine"),
                    ("item","uranium-rounds-magazine"),
                    ("item","shotgun-shell"),
                    ("item","piercing-shotgun-shell"),
                    ("item","cannon-shell"),
                    ("item","explosive-cannon-shell"),
                    ("item","uranium-cannon-shell"),
                    ("item","explosive-uranium-cannon-shell"),
                    ("item","artillery-shell"),
                    ("item","rocket"),
                    ("item","explosive-rocket"),
                    ("item","atomic-bomb"),
                    ("item","flamethrower-ammo"),
                    ("item","grenade"),
                    ("item","cluster-grenade"),
                    ("item","poison-capsule"),
                    ("item","slowdown-capsule"),
                    ("item","defender-capsule"),
                    ("item","distractor-capsule"),
                    ("item","destroyer-capsule"),
                    ("item","discharge-defense-remote"),
                    ("item","artillery-targeting-remote"),
                    ("item","light-armor"),
                    ("item","heavy-armor"),
                    ("item","modular-armor"),
                    ("item","power-armor"),
                    ("item","power-armor-mk2"),
                    ("item","solar-panel-equipment"),
                    ("item","fusion-reactor-equipment"),
                    ("item","energy-shield-equipment"),
                    ("item","energy-shield-mk2-equipment"),
                    ("item","battery-equipment"),
                    ("item","battery-mk2-equipment"),
                    ("item","personal-laser-defense-equipment"),
                    ("item","discharge-defense-equipment"),
                    ("item","belt-immunity-equipment"),
                    ("item","exoskeleton-equipment"),
                    ("item","personal-roboport-equipment"),
                    ("item","personal-roboport-mk2-equipment"),
                    ("item","night-vision-equipment"),
                    ("item","stone-wall"),
                    ("item","gate"),
                    ("item","gun-turret"),
                    ("item","laser-turret"),
                    ("item","flamethrower-turret"),
                    ("item","artillery-turret"),
                    ("item","radar"),
                    ("item","rocket-silo"),

                    ("virtual","signal-254"),
                    ("virtual","signal-255"),
                    ("virtual","signal-256"),
                    ("virtual","signal-257"),
                    ("virtual","signal-258"),
                    ("virtual","signal-259"),
                    ("virtual","signal-260"),
                    ("virtual","signal-261"),
                    ("virtual","signal-262"),
                    ("virtual","signal-263"),
                    ("virtual","signal-264"),
                    ("virtual","signal-265"),
                    ("virtual","signal-266"),
                    ("virtual","signal-267"),
                    ("virtual","signal-268"),
                    ("virtual","signal-269"),
                    ("virtual","signal-270"),
                    ("virtual","signal-271"),
                    ("virtual","signal-272"),
                    ("virtual","signal-273"),
                    ("virtual","signal-274"),
                    ("virtual","signal-275"),
                    ("virtual","signal-276"),
                    ("virtual","signal-277"),
                    ("virtual","signal-278"),
                    ("virtual","signal-279"),
                    ("virtual","signal-280"),
                    ("virtual","signal-281"),
                    ("virtual","signal-282"),
                    ("virtual","signal-283"),
                    ("virtual","signal-284"),
                    ("virtual","signal-285"),
                    ("virtual","signal-286"),
                    ("virtual","signal-287"),
                    ("virtual","signal-288"),
                    ("virtual","signal-289"),
                    ("virtual","signal-290"),
                    ("virtual","signal-291"),
                    ("virtual","signal-292"),
                    ("virtual","signal-293"),
                    ("virtual","signal-294"),
                    ("virtual","signal-295"),
                    ("virtual","signal-296"),
                    ("virtual","signal-297"),
                    ("virtual","signal-298"),
                    ("virtual","signal-299"),
                    ("virtual","signal-300"),
                    ("virtual","signal-301"),
                    ("virtual","signal-302"),
                    ("virtual","signal-303"),
                    ("virtual","signal-304"),
                    ("virtual","signal-305"),
                    ("virtual","signal-306"),
                    ("virtual","signal-307"),
                    ("virtual","signal-308"),
                    ("virtual","signal-309"),
                    ("virtual","signal-310"),
                    ("virtual","signal-311"),
                    ("virtual","signal-312"),
                    ("virtual","signal-313"),
                    ("virtual","signal-314"),
                    ("virtual","signal-315"),
                    ("virtual","signal-316"),
                    ("virtual","signal-317"),
                    ("virtual","signal-318"),
                    ("virtual","signal-319"),
                }
        );
    }
}