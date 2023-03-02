from flask import Flask, jsonify, request
import datetime 

app = Flask("restAPI")

sessionId = None

data = {
    "name": "Manuel",
    "year": 1994,
    "timestamp": str(datetime.datetime.now().timestamp())
}

# Prueba GET Endpoint
@app.route('/', methods=['GET'])
def get():
    print("new GET request!")
    return jsonify(data)

@app.route('/open_session', methods=['GET'])
def open_session():
    global sessionId
    sessionId = str(datetime.datetime.now().timestamp())

    response = {
            "message": "Sesión iniciada con éxito.",
            "sessionId": sessionId
        }

    return jsonify(response), 200
    
@app.route('/close_session', methods=['GET'])
def close_session():
    global sessionId
    sessionId = None

    response = {
            "message": "Sesión terminada con éxito.",
            "sessionId": sessionId
        }

    return jsonify(response), 200



# POST Nueva etiqueta de la posición del usuario
@app.route('/user_pos_update', methods=['POST'])
def user_pos_update():
    if sessionId != None:
        filename = sessionId+"_coords"

        # Obtenemos los parámetros enviados en la petición
        json = request.get_json()

        time = json['timestamp']
        xCoordinate = json['x']
        yCoordinate = json['y']

        print("Actualización de posicion del usuario: ", str(time)+" ("+str(xCoordinate)+", "+str(yCoordinate)+")\n")

        # Actualizamos el archivo donde almacenaremos los datos de la sesión
        f = open(filename, "a")
        f.write(str(time)+" "+
                str(xCoordinate)+" "+
                str(yCoordinate)+"\n")
        f.close()

        print("Archivo "+filename+" actualizado")

        response = {
            "message": "Actualización recibida y almacenada con éxito.",
            "sessionId": filename
        }
        return jsonify(response), 201
    else:
        print("SessionID null")
        response = {
            "message": "No existe sesión abierta.",
            "sessionId": filename
        }
        return jsonify(response), 400 # POST Bad Request

# POST Actualización de datos por lotes
@app.route('/update', methods=['POST'])
def update():
    # Comprobamos si existe una sesión activa
    if sessionId != None:
        json = request.get_json()

        # Abrimos el archivo de la sesión activa en modo "append" para no sobreescribir datos
        f = open(sessionId, "a")
        for item in json:
            # Actualizamos el archivo donde se almacenan los datos de la sesión
            f.write(item['timestamp']+" "+
                    item['distance']+" "+
                    item['mac_tag']+" "+
                    item['mac_anchor']+"\n")
        f.close()
        
        print("Archivo "+sessionId+" actualizado")

        # Preparamos la respuesta a la petición recibida
        response = {
            "message": "Actualización recibida y almacenada con éxito.",
            "sessionId": sessionId
        }

        # Envio de la respuesta en formato JSON y el código de estado
        return jsonify(response), 201
    else:
        response = {
            "message": "No existe sesión abierta.",
            "sessionId": sessionId
        }
        return jsonify(response), 400 # POST Bad Request

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5103)