#!/usr/bin/env python3
"""Escribe Resources/Consejos/<id>.json (las 12 frases de consejo de cada emoción).

Es solo la fuente de las frases: una vez escritos los JSON, se pueden editar a mano sin tocar el código.
Cada emoción habla en primera persona, con 1 o 2 frases cortas, y cada grupo de 12 mezcla:
  - qué es y para qué sirve (3)
  - cómo se nota en el cuerpo (2)
  - algo pequeño que se puede hacer cuando aparece (3)
  - una forma de acompañarla (2)
  - la idea de hablarlo con alguien de confianza (2)
Sin diagnósticos, sin tecnicismos, sin prometer curas, sin sermonear y sin decir qué debe sentir la persona.

Uso:  python tools/generar_consejos.py
"""
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CONSEJOS = {
    "rabia": [
        "Soy tu forma de decir que algo importante fue herido. No vengo a destruir, vengo a proteger.",
        "Cuando algo te parece injusto, me despierto. Sirvo para marcar tus límites.",
        "Detrás de mí casi siempre hay algo que te importa mucho. Vale la pena preguntarse qué es.",
        "Me noto en el pecho caliente, en la mandíbula apretada y en las manos cerradas. Es mi manera de prepararte.",
        "A veces el corazón me late rápido y la cara se me pone caliente. Soy yo, con mucha energía.",
        "Cuando aparezco, puedes soltar el aire despacio, como si apagaras una vela. Dos o tres veces ayuda.",
        "Si puedes, camina un poco o estira los brazos. Mi energía necesita moverse.",
        "Antes de decir algo, puedes esperar tres respiraciones. Yo no me voy a ninguna parte.",
        "Para acompañarme, pregúntame con calma qué me dolió. Suelo tener una respuesta sencilla.",
        "No hace falta que me calles ni que me obedezcas. Basta con que me escuches un momento.",
        "Si me sientes muy grande, contárselo a alguien de confianza me hace más pequeña y más clara.",
        "Hablarlo con alguien que te quiere suele aliviarme. Dos oídos pesan menos que uno.",
    ],
    "miedo": [
        "Soy tu alarma. Aparezco para avisarte de que algo podría necesitar cuidado.",
        "Mi trabajo es que te detengas un momento y mires bien. A veces me paso de prudente.",
        "No siempre tengo razón, pero siempre intento protegerte. Eso es lo único que sé hacer.",
        "Me noto en las manos frías, en el estómago encogido y en un corazón que corre. Es mi manera de ponerte en guardia.",
        "A veces me noto en las piernas que tiemblan o en una respiración corta. Es tu cuerpo escuchándome.",
        "Cuando me sientas, mira alrededor y nombra tres cosas que ves. Ayuda a recordar dónde estás.",
        "Puedes poner una mano en el pecho y respirar despacio. Me recuerda que ahora estás a salvo.",
        "Si algo me asusta mucho, se puede dividir en pasos pequeños. Un paso a la vez pesa menos.",
        "Acompáñame diciendo en voz baja que me escuchas y que gracias por avisar. Con eso suelo calmarme un poco.",
        "No tienes que ser valiente todo el tiempo. Puedes ir despacio y llevarme de la mano.",
        "Si me quedo mucho rato, cuéntale a alguien de confianza qué me asusta. Contado, me veo menos grande.",
        "Pedir compañía no es debilidad. A mí me ayuda ver que no estás a solas con esto.",
    ],
    "tristeza": [
        "Yo te ayudo a soltar lo que pesa. Llorar no es romperse, es dejar salir.",
        "Aparezco cuando algo importante cambió o se fue. Sirvo para despedirlo con cariño.",
        "Cuando estoy, el mundo se vuelve más lento. Eso también sirve, porque te deja sentir lo que pasó.",
        "Me noto en los ojos húmedos, en la garganta apretada y en el cuerpo cansado. Es mi manera de pedir descanso.",
        "A veces solo soy un peso en el pecho, como una piedra suave. No tiene que irse enseguida.",
        "Cuando aparezco, puedes tomar algo tibio o arroparte con algo suave. Los cuidados pequeños me acompañan bien.",
        "Escribir o dibujar un poco de lo que sientes me da un lugar donde quedarme.",
        "Un paseo corto, aunque sea hasta la puerta de casa, me ayuda a moverme sin prisa.",
        "Acompáñame sin intentar arreglarme. A veces solo quiero que alguien se siente a mi lado.",
        "Puedes decirme que está bien que esté aquí. Me quedo más tranquila cuando me aceptan.",
        "Si pesa mucho, contarle a alguien de confianza lo que pasó me hace más liviana.",
        "Un abrazo, o una charla con alguien que te quiere, me cuida mejor que muchas palabras.",
    ],
    "soledad": [
        "Te recuerdo que las personas necesitamos a otras personas. Vengo a pedir cercanía.",
        "Aparezco cuando falta compañía, o cuando hay gente pero nadie te ve de verdad. Sirvo para buscar un lugar donde pertenecer.",
        "Estar a solas a ratos puede ser bonito. Yo me noto cuando deja de ser elegido y empieza a pesar.",
        "Me noto en un vacío en el pecho y en las ganas de que alguien escriba. Es mi manera de decir que hay un hueco.",
        "A veces el cuerpo se queda quieto y callado, como esperando. Eso también soy yo.",
        "Cuando aparezco, puedes mandar un mensaje corto a alguien. Un hola pequeño basta para empezar.",
        "Salir adonde haya gente, aunque sea a mirar, me hace sentir más cerca.",
        "Cuidar una planta, una mascota o una rutina me da sensación de compañía mientras llegan los demás.",
        "Acompáñame hablándome con amabilidad, como lo harías con una amistad que está triste.",
        "No me ayudas llenándome de ruido. Me ayudas con un rato de compañía de verdad, aunque sea corto.",
        "Si me notas mucho tiempo, cuéntaselo a alguien en quien confíes. Decirlo ya es un acercamiento.",
        "Pedir compañía no es molestar. Casi siempre, quien te quiere se alegra de que se lo pidas.",
    ],
    "culpa": [
        "Aparezco cuando sientes que algo que hiciste dañó a alguien. Sirvo para invitarte a reparar.",
        "No vengo a castigarte. Vengo a mostrarte que te importan los demás.",
        "Cuando entiendes lo que quiero decirte, ya hice mi trabajo y puedo bajar el volumen.",
        "Me noto en el estómago apretado y en pensamientos que dan vueltas a lo mismo. Es mi manera de insistir.",
        "A veces soy un nudo en el pecho y ganas de esconderse. Eso también soy yo.",
        "Cuando aparezco, puedes preguntarte qué sí está en tus manos arreglar. Una cosa pequeña ya cuenta.",
        "Pedir perdón con sinceridad, o hacer algo amable para reparar, suele ser lo que de verdad necesito.",
        "Si no se puede arreglar, pensar qué harías distinto la próxima vez también es una forma de reparar.",
        "Acompáñame hablándote como le hablarías a una amistad que se equivocó, con firmeza y con cariño.",
        "Equivocarse es parte de ser persona. Yo existo precisamente porque te importa hacerlo bien.",
        "Si pesa demasiado, cuéntaselo a alguien de confianza. Visto desde fuera, casi siempre se ve más pequeño.",
        "A veces otra persona ayuda a ver qué fue tu parte y qué no. No hace falta cargarlo a solas.",
    ],
    "ansiedad": [
        "Yo te preparo para lo que viene. A veces me acelero y me paso un poquito.",
        "Aparezco cuando algo importante está por pasar. Sirvo para que lo tengas en cuenta.",
        "Mi trabajo es imaginar lo que podría salir mal para que llegues con tiempo y cuidado. Pero no siempre sale así.",
        "Me noto en el corazón rápido, en la respiración corta y en las manos inquietas. Es mi manera de decir atención.",
        "A veces la cabeza va muy deprisa y el cuerpo se queda tenso. Eso también soy yo.",
        "Cuando aparezco, puedes soltar el aire despacio, más largo que el aire que tomas. Tres veces.",
        "Prueba a mirar cinco cosas a tu alrededor y a tocar algo que tengas cerca. Me ayuda a volver al ahora.",
        "Puedes escribir lo que te preocupa y elegir una sola cosa que hoy esté en tus manos.",
        "Acompáñame sin pedirme que me calle. Dime que vas conmigo y avanza a tu ritmo.",
        "Beber agua despacio, estirarte o salir un momento al aire libre me hace bajar el ritmo.",
        "Si me quedo mucho tiempo, cuéntale a alguien de confianza lo que te preocupa. Compartirme me aligera.",
        "No tienes que resolver todo hoy. A veces otra persona ve un camino que tú todavía no ves.",
    ],
    "verguenza": [
        "Cuido cómo te ven los demás porque la gente te importa. Soy parte de querer pertenecer.",
        "Aparezco cuando sientes que te miran o que algo tuyo quedó a la vista. Sirvo para que cuides lo que muestras.",
        "No quiero que te escondas para siempre. Solo quiero que muestres lo que quieras, cuando quieras.",
        "Me noto en las mejillas calientes, en la mirada que baja y en las ganas de desaparecer. Es mi manera de pedir cuidado.",
        "A veces la voz me sale bajita y el cuerpo se encoge. Eso también soy yo.",
        "Cuando aparezco, puedes respirar hondo y recordar que casi nadie guarda en la memoria los tropiezos de los demás.",
        "Prueba a sonreírte y a decirte que te pasó y que puedes seguir.",
        "Mostrar un poquito de ti cada vez, en un lugar seguro, me va quitando peso.",
        "Acompáñame tratándote con la misma ternura que tendrías con alguien querido que se equivocó.",
        "Todo el mundo ha pasado por momentos así. Que a ti te pase no te hace menos.",
        "Contarle a alguien de confianza lo que te dio vergüenza suele convertirlo en una anécdota.",
        "Cuando lo hablas con alguien que te quiere, me hago pequeña. A mí me ayuda que te escuchen con cariño.",
    ],
}


def main() -> None:
    carpeta = os.path.join(RAIZ, "Resources", "Consejos")
    os.makedirs(carpeta, exist_ok=True)
    total = 0
    for id_, frases in CONSEJOS.items():
        assert len(frases) == 12, id_
        for f in frases:
            assert not any(c in f for c in ":[]{}"), "signo prohibido en: " + f
        with open(os.path.join(carpeta, id_ + ".json"), "w", encoding="utf-8", newline="\n") as archivo:
            json.dump({"id": id_, "frases": frases}, archivo, ensure_ascii=False, indent=1)
            archivo.write("\n")
        total += len(frases)
    print("Escritos %d consejos en %s" % (total, carpeta))


if __name__ == "__main__":
    main()
